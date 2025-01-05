//
//  Sora_JSApp.swift
//  Sora-JS
//
//  Created by Francesco on 04/01/25.
//

import SwiftUI

@main
struct Sora_JSApp: App {
    @StateObject private var settings = Settings()
    @StateObject private var moduleManager = ModuleManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(moduleManager)
                .environmentObject(settings)
                .accentColor(settings.accentColor)
                .onAppear {
                    settings.updateAppearance()
                }
        }
    }
}
