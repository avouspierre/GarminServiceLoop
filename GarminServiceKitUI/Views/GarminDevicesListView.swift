//
//  ServiceStatus.swift
//  NightscoutServiceKitUI
//
//  Created by Pete Schwamb on 9/30/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKitUI
import GarminServiceKit

struct GarminDevicesListView: View, HorizontalSizeClassOverride {
    @Environment(\.dismissAction) private var dismiss
    @ObservedObject var viewModel: GarminDevicesAttachViewModel

   // @State private var selectedItem: String?
    
    
    var body: some View {
        VStack {
            Text("Garmin")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Image(frameworkImage: "garmin", decorative: true)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 150, height: 150)
            

            VStack(spacing: 0) {
                HStack {
                    Text("Device")
                    Spacer()
                    if (!self.viewModel.service.listDevices().isEmpty) {
                        
                        ForEach(self.viewModel.service.listDevices(), id: \.uuid) { device in
                                Text(device.friendlyName)
                            }
                        
                    }
                }
                .padding()
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            
            Button(action: {self.viewModel.attemptFindDevice()}) {
                Text("Select device").padding(.top, 20)
            }
        }
        .padding([.leading, .trailing])
        .navigationBarTitle("")
        .navigationBarItems(trailing: dismissButton)
    }
    
    private var dismissButton: some View {
        Button(action: dismiss) {
            Text("Done").bold()
        }
    }
}
