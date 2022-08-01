//
//  GarminManager.swift
//  GarminServiceKit
//
//  Created by Pierre LAGARDE on 24/07/2022.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Combine
import ConnectIQ
import Foundation
import OSLog
import LoopKit
import HealthKit

protocol GarminManager {
    func selectDevices() -> AnyPublisher<[IQDevice], Never>
    var devices: [IQDevice] { get }
    func sendState(_ data: Data)
    var stateRequet: (() -> (Data))? { get set }
}

extension Notification.Name {
    static let openFromGarminConnect = Notification.Name("Notification.Name.openFromGarminConnect")
}

final class BaseGarminManager: NSObject, GarminManager {
    private let log = OSLog(category: "Garmin Manager")
    
    private enum Config {
        static let watchfaceUUID = UUID(uuidString: "EC3420F6-027D-49B3-B45F-D81D6D3ED90B") //Garmin Loop WatchFace
        static let watchdataUUID = UUID(uuidString: "71CF0982-CA41-42A5-8441-EA81D36056C4") //Garmin Loop DataField
    }

    private let connectIQ = ConnectIQ.sharedInstance()

    private var watchfaces: [IQApp] = []

    var stateRequet: (() -> (Data))?

    private let stateSubject = PassthroughSubject<NSDictionary, Never>()
    

    private(set) var devices: [IQDevice] = [] {
        didSet {
            saveDevices(persistedDevices: devices.map(CodableDevice.init))
            watchfaces = []
            devices.forEach { device in
                connectIQ?.register(forDeviceEvents: device, delegate: self)
                let watchfaceApp = IQApp(
                    uuid: Config.watchfaceUUID,
                    store: UUID(),
                    device: device
                )
                let watchDataFieldApp = IQApp(
                    uuid: Config.watchdataUUID,
                    store: UUID(),
                    device: device
                )
                watchfaces.append(watchfaceApp!)
                watchfaces.append(watchDataFieldApp!)
                connectIQ?.register(forAppMessages: watchfaceApp, delegate: self)
                connectIQ?.register(forAppMessages: watchDataFieldApp, delegate: self)
            }
        }
    }

    //private var lifetime = Lifetime()
    private var cancellables: Set<AnyCancellable> = []
    
    private var selectPromise: Future<[IQDevice], Never>.Promise?

    override init() {
        super.init()
        let appMainIdentifier = HKSource.default().bundleIdentifier // find the identifier of the app
        
        connectIQ?.initialize(withUrlScheme: appMainIdentifier, uiOverrideDelegate: self)
        
        restoreDevices()
        subscribeToOpenFromGarminConnect()
        setupApplications()
        subscribeState()
    }

    private func subscribeToOpenFromGarminConnect() {
        NotificationCenter.default
            .publisher(for: .openFromGarminConnect)
            .sink { notification in
               guard let url = notification.object as? URL else { return }
                self.parseDevicesFor(url: url)
            }
            .store(in: &cancellables)
        
        
        NotificationCenter.default
            .publisher(for: .openFromGarminConnect)
            .sink { notification in
                guard let url = notification.object as? URL else { return }
                self.parseDevicesFor(url: url)
            }
            .store(in: &cancellables)
    }

    private func subscribeState() {
        func sendToWatchface(state: NSDictionary) {
            watchfaces.forEach { app in
                connectIQ?.getAppStatus(app) { status in
                    guard status?.isInstalled ?? false else {
                        self.log.debug("Garmin: watchface app not installed")
                        return
                    }
                    self.log.debug("Garmin: sending message to watchface")
                    self.sendMessage(state, to: app)
                }
            }
        }

        stateSubject
            .throttle(for: .seconds(10), scheduler: DispatchQueue.main, latest: true)
            .sink { state in
                sendToWatchface(state: state)
            }
            .store(in: &cancellables)
  //          .store(in: &lifetime)
    }

    private func restoreDevices() {
        //devices = persistedDevices.map(\.iqDevice)
        let decoder = JSONDecoder()
        guard let devicesAsString = try? KeychainManager().getGarminCredentials(),
              let devicesAsData = devicesAsString.data(using: String.Encoding.utf8),
              let devicesFromjson = try? decoder.decode([CodableDevice].self,from:devicesAsData)
        else {
            //delete the KeyChain Value to re-init all in case of error
            try? KeychainManager().setGarminCredentials(devicesAsString: "")
            return
        }
        
        devices = devicesFromjson.map(\.iqDevice)
    }

    private func parseDevicesFor(url: URL) {
        devices = connectIQ?.parseDeviceSelectionResponse(from: url) as? [IQDevice] ?? []
        selectPromise?(.success(devices))
        selectPromise = nil
    }

    private func setupApplications() {
        devices.forEach { _ in
        }
    }

    func selectDevices() -> AnyPublisher<[IQDevice], Never> {
        Future { promise in
            self.selectPromise = promise
            self.connectIQ?.showDeviceSelection()
        }
        .timeout(120, scheduler: DispatchQueue.main)
        .replaceEmpty(with: [])
        .eraseToAnyPublisher()
    }

    func sendState(_ data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: []) as? NSDictionary else {
            return
        }
        stateSubject.send(object)
    }

    private func sendMessage(_ msg: NSDictionary, to app: IQApp) {
        connectIQ?.sendMessage(msg, to: app, progress: { sent, all in
            self.log.debug("Garmin: sending progress")
        }, completion: { result in
            if result == .success {
                self.log.debug("Garmin: message sent")
            } else {
                self.log.debug("Garmin: message failed")
            }
        })
    }
    
    private func saveDevices(persistedDevices: [CodableDevice]) {
        guard let jsonData = try? JSONEncoder().encode(persistedDevices),
                  let jsonString = String(data: jsonData, encoding: .utf8)
        else { return }
        try? KeychainManager().setGarminCredentials(devicesAsString: jsonString)
    }
}

extension BaseGarminManager: IQUIOverrideDelegate {
    func needsToInstallConnectMobile() {}
}

extension BaseGarminManager: IQDeviceEventDelegate {
    func deviceStatusChanged(_ device: IQDevice, status: IQDeviceStatus) {
        switch status {
        case .invalidDevice:
            self.log.debug("Garmin: invalidDevice")
        case .bluetoothNotReady:
            self.log.debug("Garmin: bluetoothNotReady")
        case .notFound:
            self.log.debug("Garmin: notFound")
        case .notConnected:
            self.log.debug("Garmin: notConnected")
        case .connected:
            self.log.debug("Garmin: connected")
        @unknown default:
            self.log.debug("Garmin: unknown state")
        }
    }
}

extension BaseGarminManager: IQAppMessageDelegate {
    func receivedMessage(_ message: Any, from app: IQApp) {
        print("ASDF: got message: \(message) from app: \(app.uuid!)")
        if let status = message as? String, status == "status", let watchState = stateRequet?() {
            sendState(watchState)
        }
    }
}

struct CodableDevice: Codable, Equatable {
    let id: UUID
    let modelName: String
    let friendlyName: String

    init(iqDevice: IQDevice) {
        id = iqDevice.uuid
        modelName = iqDevice.modelName
        friendlyName = iqDevice.modelName
    }

    var iqDevice: IQDevice {
        IQDevice(id: id, modelName: modelName, friendlyName: friendlyName)
    }
}

extension KeychainManager {

    func setGarminCredentials(devicesAsString: String? = nil) throws {
            try replaceGenericPassword(devicesAsString, forService: GarminDevices)
    }

    func getGarminCredentials() throws -> (String) {
        return try getGenericPasswordForService(GarminDevices)
    }

}

fileprivate let GarminDevices = "GarminDevices"



