//
//  SettingsViewPlayer.swift
//  Sora
//
//  Created by Francesco on 31/01/25.
//

import SwiftUI

struct SettingsViewPlayer: View {
    @AppStorage("externalPlayer") private var externalPlayer: String = "Default"
    @AppStorage("alwaysLandscape") private var isAlwaysLandscape = false
    @AppStorage("hideNextButton") private var isHideNextButton = false
    @AppStorage("rememberPlaySpeed") private var isRememberPlaySpeed = false
    @AppStorage("holdSpeedPlayer") private var holdSpeedPlayer: Double = 2.0
    
    private let mediaPlayers = ["Default", "VLC", "OutPlayer", "Infuse", "nPlayer", "Sora"]
    
    var body: some View {
        Form {
            Section(header: Text("Media Player"), footer: Text("Some features are limited to the Sora and Default player, such as ForceLandscape and holdSpeed")) {
                HStack {
                    Text("Media Player")
                    Spacer()
                    Menu(externalPlayer) {
                        ForEach(mediaPlayers, id: \.self) { player in
                            Button(action: {
                                externalPlayer = player
                            }) {
                                Text(player)
                            }
                        }
                    }
                }
                
                Toggle("Hide 'Watch Next' after 5s", isOn: $isHideNextButton)
                    .tint(.accentColor)
                
                Toggle("Force Landscape", isOn: $isAlwaysLandscape)
                    .tint(.accentColor)
            }
            
            Section(header: Text("Speed Settings")) {
                Toggle("Remember Playback speed", isOn: $isRememberPlaySpeed)
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
