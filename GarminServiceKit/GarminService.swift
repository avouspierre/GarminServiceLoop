//
//  GarminService
//
//  Created by Pierre Lagarde on 7/20/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import os.log
import HealthKit
import LoopKit
import ConnectIQ
import Combine

public enum GarminServiceError: Error {
    case incompatibleTherapySettings
    case missingCredentials
}


public final class GarminService: Service {

    public static let serviceIdentifier = "GarminService"

    public static let localizedTitle = LocalizedString("Garmin", comment: "The title of the Garmin service")
    
   public weak var serviceDelegate: ServiceDelegate?
    
    private var garmin: GarminManager!
    
    private var cancellables: Set<AnyCancellable> = []
    
    public var isOnboarded: Bool
    
    private var uploader: GarminUploader
    
    private let log = OSLog(category: "GarminService")

    public init() {
        self.isOnboarded = false
        self.garmin = BaseGarminManager()
        self.uploader = GarminUploader(garmin: self.garmin)
    }

    public required init?(rawState: RawStateValue) {
        self.isOnboarded = rawState["isOnboarded"] as? Bool ?? true   // Backwards compatibility
        
        self.garmin = BaseGarminManager()
        self.uploader = GarminUploader(garmin: self.garmin)
        
    }

    public var rawState: RawStateValue {
        return [
            "isOnboarded": isOnboarded
        ]
    }

    public var lastDosingDecisionForAutomaticDose: StoredDosingDecision?

    public var hasConfiguration: Bool { return !self.garmin.devices.isEmpty}

    public func verifyConfiguration(completion: @escaping (Error?) -> Void) {
        guard hasConfiguration else {
            completion(GarminServiceError.missingCredentials)
            return
        }
    }

    public func completeCreate() {
       
    }

    public func completeOnboard() {
        isOnboarded = true
        serviceDelegate?.serviceDidUpdateState(self)
    }

    public func completeUpdate() {
        serviceDelegate?.serviceDidUpdateState(self)
    }

    public func completeDelete() {
        //todo to delete all
        serviceDelegate?.serviceWantsDeletion(self)
    }
    
    public func listDevices() -> [IQDevice] {
        return garmin.devices
    }

    
    public func selectDevices(completion: @escaping (Error?) -> Void) {
        garmin.selectDevices()
            .receive(on: DispatchQueue.main)
            .sink { value in
                completion(nil)
            }
            .store(in: &cancellables)
    }
    
}

extension GarminService: RemoteDataService {
    
    public func uploadTemporaryOverrideData(updated: [LoopKit.TemporaryScheduleOverride], deleted: [LoopKit.TemporaryScheduleOverride], completion: @escaping (Result<Bool, Error>) -> Void) {
       
            completion(.success(true))
            return
    }


    public var alertDataLimit: Int? { return 2 }

    public func uploadAlertData(_ stored: [SyncAlertObject], completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(false))
    }

    public var carbDataLimit: Int? { return 1 }

    public func uploadCarbData(created: [SyncCarbObject], updated: [SyncCarbObject], deleted: [SyncCarbObject], completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(true))
        

    }

    public var doseDataLimit: Int? { return 1000 }

    public func uploadDoseData(created: [DoseEntry], deleted: [DoseEntry], completion: @escaping (_ result: Result<Bool, Error>) -> Void) {
        completion(.success(true))


    }

    public var dosingDecisionDataLimit: Int? { return Int.max }  // Each can be up to 20K bytes of serialized JSON, target ~1M or less

    public func uploadDosingDecisionData(_ stored: [StoredDosingDecision], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard hasConfiguration else {
            completion(.success(true))
            return
        }
        
        guard let lastDecisionValue: StoredDosingDecision = stored.last else {
            completion(.success(false))
            return
        }
        
        uploader.uploadDeviceStatuses(lastDecisionValue) { result in
            switch result {
            case .success:
                self.lastDosingDecisionForAutomaticDose = nil
            default:
                break
            }
            completion(result)
        }
        
    }

    public var glucoseDataLimit: Int? { return 2 }

    public func uploadGlucoseData(_ stored: [StoredGlucoseSample], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard hasConfiguration else {
            completion(.success(true))
            return
        }
        uploader.sendLastGlucose(stored, completion: completion)
    }

    public var pumpEventDataLimit: Int? { return 1 }

    public func uploadPumpEventData(_ stored: [PersistedPumpEvent], completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(false))
    }

    public var settingsDataLimit: Int? { return 400 }  // Each can be up to 2.5K bytes of serialized JSON, target ~1M or less

    public func uploadSettingsData(_ stored: [StoredSettings], completion: @escaping (Result<Bool, Error>) -> Void) {
        guard hasConfiguration else {
            completion(.success(true))
            return
        }
    }
    
    public func validatePushNotificationSource(_ notification: [String: AnyObject]) -> Bool {
            return false
    }
    
    public func fetchStoredTherapySettings(completion: @escaping (Result<(TherapySettings,Date), Error>) -> Void) {

            completion(.failure(GarminServiceError.missingCredentials))
            return

    }

}


