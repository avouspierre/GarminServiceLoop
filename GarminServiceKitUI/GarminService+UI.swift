//
//  GarminService+UI.swift
//  GarminServiceKitUI
//
//  Created by Pierre Lagarde 07/23/22
//  Copyright © 2019 LoopKit Authors. All rights reserved.


import SwiftUI
import LoopKit
import LoopKitUI
import GarminServiceKit

extension GarminService: ServiceUI {
    public static var image: UIImage? {
        UIImage(named: "garmin", in: Bundle(for: ServiceUICoordinator.self), compatibleWith: nil)!
    }

    public static func setupViewController(colorPalette: LoopUIColorPalette) -> SetupUIResult<ServiceViewController, ServiceUI> {
        return .userInteractionRequired(ServiceUICoordinator(colorPalette: colorPalette))
    }

    public func settingsViewController(colorPalette: LoopUIColorPalette) -> ServiceViewController {
        return ServiceUICoordinator(service: self, colorPalette: colorPalette)
    }
}
