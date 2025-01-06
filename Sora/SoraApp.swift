//
//  SoraApp.swift
//  Sora
//
//  Created by Francesco on 06/01/25.
//

import SwiftUI

@main
struct SoraApp: App {
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
