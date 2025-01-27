//
//  SettingsViewUI.swift
//  Sora
//
//  Created by Francesco on 27/01/25.
//

import SwiftUI

struct SettingsViewUI: View {
    @AppStorage("episodeChunkSize") private var episodeChunkSize: Int = 100
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        Form {
            Section(header: Text("Interface")) {
                ColorPicker("Accent Color", selection: $settings.accentColor)
                HStack() {
                    Text("Appearance")
                    Picker("Appearance", selection: $settings.selectedAppearance) {
                        Text("System").tag(Appearance.system)
                        Text("Light").tag(Appearance.light)
                        Text("Dark").tag(Appearance.dark)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            
            Section(header: Text("Episode Chunk Size")) {
                Text("Chunk Size")
                Spacer()
                Menu {
                    Button(action: { episodeChunkSize = 25 }) {
                        Text("25")
                    }
                    Button(action: { episodeChunkSize = 50 }) {
                        Text("50")
                    }
                    Button(action: { episodeChunkSize = 75 }) {
                        Text("75")
                    }
                    Button(action: { episodeChunkSize = 100 }) {
                        Text("100")
                    }
                } label: {
                    Text("\(episodeChunkSize)")
                }
            }
        }
        .navigationTitle("UI Settings")
    }
}
