//
//  NightscoutUploader.swift
//  NightscoutServiceKit
//
//  Created by Pierre Lagarde
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import LoopKit
import Foundation
import Combine
import OSLog
import HealthKit
import NightscoutUploadKit


// FreeAPSX source
struct WatchState: Codable {
    var glucose: String?
    var trend: String?
    var trendRaw: String?
    var delta: String?
    var glucoseDate: Date?
    var glucoseDateInterval: UInt64?
    var lastLoopDate: Date?
    var lastLoopDateInterval: UInt64?
//    var bolusIncrement: Decimal?
//    var maxCOB: Decimal?
//    var maxBolus: Decimal?
//    var carbsRequired: Decimal?
//    var bolusRecommended: Decimal?
    var iob: Decimal?
    var cob: Decimal?
 //  var tempTargets: [TempTargetWatchPreset] = []
    var bolusAfterCarbs: Bool?
  //  var eventualBG: String? - not use in fact
    var eventualBGRaw: String?
}




public class GarminUploader {
    private let log = OSLog(category: "Garmin Uploader")
    
    private var state = WatchState()
    
    private var garmin: GarminManager!
    
    init(garmin: GarminManager) {
        self.garmin = garmin
    }
    
    private var deltaFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "+"
        return formatter
    }
    
    private func sendState() {
       // dispatchPrecondition(condition: .onQueue(processQueue))
        guard let data = try? JSONEncoder().encode(state) else {
            self.log.debug("Cannot encode watch state")
            return
        }
        garmin.sendState(data)

       // guard session.isReachable else { return }
       //session.sendMessageData(data, replyHandler: nil) { error in
       //     warning(.service, "Cannot send message to watch", error: error)
       // }
    }
    
    private var glucoseFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
//        if settingsManager.settings.units == .mmolL {
//            formatter.minimumFractionDigits = 1
//            formatter.maximumFractionDigits = 1
//        }
        formatter.roundingMode = .halfUp
        return formatter
    }
    
    private var eventualFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }

    func sendLastGlucose(_ samples: [StoredGlucoseSample], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard !samples.isEmpty else {
            completion(.success(false))
            return
        }
        // only One value in the storage ! If not the case, send only the first one
        let glucose: StoredGlucoseSample = samples[0]
        let glucoseVal: HKQuantity = glucose.quantity
        let unit:HKUnit =  HKUnit.milligramsPerDeciliter // force here
        
        let delta:Double = samples.count >= 2 ? glucoseVal.doubleValue(for: unit) - samples[1].quantity.doubleValue(for: unit) : 0

        let glucoseText = glucoseFormatter
            .string(from: Double(glucoseVal.doubleValue(for: unit)) as NSNumber)!
       
        
        let directionText: String = glucose.trend?.symbol ?? ""
        
        
        let deltaText: String? = self.deltaFormatter
                    .string(from: Double(delta) as NSNumber)
        
        let trendRawText: String? = "\(glucose.trend?.rawValue ?? 0)"
    
        self.state.trend = directionText
        self.state.glucose = glucoseText
        self.state.delta = deltaText
        self.state.trendRaw = trendRawText
        
        self.state.glucoseDate = glucose.startDate
        
        sendState()
        completion(.success(true))
    }
    
    
    public func uploadDeviceStatuses(_ lastStoreDecision: StoredDosingDecision , completion: @escaping (Result<Bool, Error>) -> Void) {
        
        //iob state
        self.state.iob = Decimal(Double(rawValue: (lastStoreDecision.insulinOnBoard?.value)!) ?? 0)
        
        //cob
        let cob: Double = lastStoreDecision.carbsOnBoard?.quantity.doubleValue(for: .gram()) ?? 0
        self.state.cob = Decimal(cob)
        
        
        // eventualBG
        let lastPredictedGlucose:PredictedGlucoseValue? = lastStoreDecision.predictedGlucose?.last
        let lastPredictedGlucoseDouble: Double? = lastPredictedGlucose?.quantity.doubleValue(for: .milligramsPerDeciliter)
        
        if let eventualBGDouble = lastPredictedGlucoseDouble {
            let eventualBGRawText = eventualFormatter.string(
                from: eventualBGDouble as NSNumber)!
            self.state.eventualBGRaw = eventualBGRawText
           
        } else {
            self.state.eventualBGRaw = "--"
           
        }
       
        
        // last loop date
        let lastDate: Date = lastStoreDecision.date
        self.state.lastLoopDate = lastDate
        self.state.lastLoopDateInterval = self.state.lastLoopDate.map { UInt64($0.timeIntervalSince1970) }
        
        
        // see the last value of Glucose
        let lastHistoGlucose: HistoricalGlucoseValue? = lastStoreDecision.historicalGlucose?.last
        
        let unit:HKUnit =  HKUnit.milligramsPerDeciliter // force here
        
        //check the glucose in regard of the date available
        if let lastHistoGlucoseDate: Date = lastHistoGlucose?.startDate,
           let glucoseVal: HKQuantity = lastHistoGlucose?.quantity {
            if let existingGlucoseDate: Date = self.state.glucoseDate
                 {
                    if (existingGlucoseDate < lastHistoGlucoseDate) {
                        self.state.glucoseDate = lastHistoGlucoseDate
                        self.state.glucose = glucoseFormatter
                            .string(from: Double(glucoseVal.doubleValue(for: unit)) as NSNumber)!
                        
                        
                        // delta calculation
                        let countHistoGlucose = lastStoreDecision.historicalGlucose?.count ?? 0
                        if (countHistoGlucose > 2) {
                            let previousHistoGlucose: HistoricalGlucoseValue? = lastStoreDecision.historicalGlucose?[countHistoGlucose-2]
                            if let previousHistGlucoseVal = previousHistoGlucose?.quantity {
                                let delta:Double = glucoseVal.doubleValue(for: unit) - previousHistGlucoseVal.doubleValue(for: unit)
                                let deltaText: String? = self.deltaFormatter
                                            .string(from: Double(delta) as NSNumber)
                                self.state.delta = deltaText
                            }
                        }
                    }
                } else {
                    // no value for Glucose indeed.
                    // to improve !!
                    self.state.glucoseDate = lastHistoGlucoseDate
                    self.state.glucose = glucoseFormatter
                        .string(from: Double(glucoseVal.doubleValue(for: unit)) as NSNumber)!
                    
                    //To improve because duplication
                    let countHistoGlucose = lastStoreDecision.historicalGlucose?.count ?? 0
                    if (countHistoGlucose > 2) {
                        let previousHistoGlucose: HistoricalGlucoseValue? = lastStoreDecision.historicalGlucose?[countHistoGlucose-2]
                        if let previousHistGlucoseVal = previousHistoGlucose?.quantity {
                            let delta:Double = glucoseVal.doubleValue(for: unit) - previousHistGlucoseVal.doubleValue(for: unit)
                            let deltaText: String? = self.deltaFormatter
                                        .string(from: Double(delta) as NSNumber)
                            self.state.delta = deltaText
                        }
                    }
                    
                }
        }
        
    
        sendState()
        completion(.success(true))
    }

}


