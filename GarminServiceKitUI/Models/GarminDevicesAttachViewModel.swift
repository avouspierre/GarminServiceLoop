//
//  CredentialsViewModel.swift
//  NightscoutServiceKitUI
//
//  Created by Pete Schwamb on 9/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import GarminServiceKit
import LoopKit

public enum GarminDevicesAttachError: Error {
    case invalidLinkApp //the garmin app is not available
}

class GarminDevicesAttachViewModel: ObservableObject {
    @Published var isVerifying: Bool
    @Published var error: Error?

    var service: GarminService
    
    var didSucceed: (() -> Void)?
    var didCancel: (() -> Void)?

    init(service: GarminService) {
        self.service = service
        isVerifying = false
    }
    
    func attemptFindDevice() {
        isVerifying = true
        self.error = nil
        
        service.selectDevices { (error) in
            DispatchQueue.main.async {
                self.isVerifying = true
                self.error = error

                if error == nil {
                    self.didSucceed?()
                }
            }
        }
    }
}
