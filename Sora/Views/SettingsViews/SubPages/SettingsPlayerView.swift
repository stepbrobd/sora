//
//  SettingsPlayerView.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI

struct SettingsPlayerView: View {
    @AppStorage("externalPlayer") private var externalPlayer: String = "Default"
    @AppStorage("AlwaysLandscape") private var isAlwaysLandscape = false
    @AppStorage("hideNextButton") private var isHideNextButton = false
    @AppStorage("holdSpeedPlayer") private var holdSpeedPlayer: Double = 2.0
    
    var body: some View {
        Form {
            Section(header: Text("Media Player"), footer: Text("The Force Landscape and HoldSpeed only work inside the default iOS player and Sora player.")) {
                HStack {
                    Text("Media Player")
                    Spacer()
                    Menu(externalPlayer) {
                        Button(action: {
                            externalPlayer = "Default"
                        }) {
                            Label("Default", systemImage: externalPlayer == "Default" ? "checkmark" : "")
                        }
                        Button(action: {
                            externalPlayer = "VLC"
                        }) {
                            Label("VLC", systemImage: externalPlayer == "VLC" ? "checkmark" : "")
                        }
                        Button(action: {
                            externalPlayer = "OutPlayer"
                        }) {
                            Label("OutPlayer", systemImage: externalPlayer == "OutPlayer" ? "checkmark" : "")
                        }
                        Button(action: {
                            externalPlayer = "Infuse"
                        }) {
                            Label("Infuse", systemImage: externalPlayer == "Infuse" ? "checkmark" : "")
                        }
                        Button(action: {
                            externalPlayer = "nPlayer"
                        }) {
                            Label("nPlayer", systemImage: externalPlayer == "nPlayer" ? "checkmark" : "")
                        }
                        Button(action: {
                            externalPlayer = "Sora"
                        }) {
                            Label("Sora", systemImage: externalPlayer == "Sora" ? "checkmark" : "")
                        }
                    }
                }
                
                Toggle("Hide 'Watch Next' after 5s", isOn: $isHideNextButton)
                    .tint(.accentColor)
                
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

