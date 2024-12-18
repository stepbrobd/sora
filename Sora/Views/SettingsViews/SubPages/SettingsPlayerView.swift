//
//  SettingsPlayerView.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI

struct SettingsPlayerView: View {
    @AppStorage("externalPlayer") private var externalPlayer: String = "Default"
    @AppStorage("alwaysLandscape") private var isAlwaysLandscape = false
    @AppStorage("holdSpeedPlayer") private var holdSpeedPlayer: Double = 2.0
    
    var body: some View {
        Form {
            Section(header: Text("Player"), footer: Text("The ForceLandscape and HoldSpeed only work inside the default iOS player.")) {
                HStack {
                    Text("Media Player")
                    Spacer()
                    Menu(externalPlayer) {
                        Button("Default") {
                            externalPlayer = "Default"
                        }
                        Button("VLC") {
                            externalPlayer = "VLC"
                        }
                        Button("OutPlayer") {
                            externalPlayer = "OutPlayer"
                        }
                        Button("Infuse") {
                            externalPlayer = "Infuse"
                        }
                        Button("nPlayer") {
                            externalPlayer = "nPlayer"
                        }
                    }
                }
                
                Toggle("Force Landscape", isOn: $isAlwaysLandscape)
                
                HStack {
                    Text("Hold Speed:")
                    Spacer()
                    Stepper(
                        value: $holdSpeedPlayer,
                        in: 0.25...2.0,
                        step: 0.25
                    ) {
                        Text(String(format: "%.2f", holdSpeedPlayer))
                    }
                }
            }
        }
        .navigationTitle("Player")
    }
}

