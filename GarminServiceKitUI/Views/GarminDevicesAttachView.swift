//
//  CredentialsView.swift
//  NightscoutServiceKitUI
//
//  Created by Pete Schwamb on 9/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKitUI
import GarminServiceKit

struct GarminDeviceAttachView: View, HorizontalSizeClassOverride {
    @ObservedObject var viewModel: GarminDevicesAttachViewModel
    @ObservedObject var keyboardObserver = KeyboardObserver()
    
    var allowCancel: Bool
    
    var body: some View {
        VStack {
            Text(LocalizedString("Garmin device", comment: "Garmin device selection"))
                .font(.largeTitle)
                .fontWeight(.semibold)
            Image(frameworkImage: "garmin", decorative: true)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 150, height: 150)
            
            
            if self.viewModel.error != nil {
                Text(String(describing: self.viewModel.error!))
            }

            Button(action: {self.viewModel.attemptFindDevice() } ) {
                if self.viewModel.isVerifying {
                    ActivityIndicator(isAnimating: .constant(true), style: .medium)
                } else {
                    Text(LocalizedString("Select device", comment: "Button text to select a garmin device"))
                }
            }
            .buttonStyle(ActionButtonStyle(.primary))
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            
            if allowCancel {
                Button(action: { self.viewModel.didCancel?() } ) {
                    Text(LocalizedString("Cancel", comment: "Button text to cancel Garmin device selection")).padding(.top, 20)
                }
            }
        }
        .padding([.leading, .trailing])
        .offset(y: -keyboardObserver.height*0.4)
        .navigationBarHidden(allowCancel)
        .navigationBarTitle("")
    }
}


struct GarminDevicesAttachView_Previews: PreviewProvider {
    static var previews: some View {
        GarminDeviceAttachView(viewModel: GarminDevicesAttachViewModel(service: GarminService()), allowCancel: true)
        .environment(\.colorScheme, .dark)
    }
}
