//
//  SoraApp.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI

@main
struct SoraApp: App {
    @StateObject private var settings = Settings()
    @StateObject private var modulesManager = ModulesManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(modulesManager)
                .accentColor(settings.accentColor)
                .onAppear {
                    settings.updateAppearance()
                }
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }
    
    private func handleURL(_ url: URL) {
        guard url.scheme == "sora",
              url.host == "module",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let moduleURL = components.queryItems?.first(where: { $0.name == "url" })?.value else {
                  return
              }
        
        modulesManager.addModule(from: moduleURL) { result in
            switch result {
            case .success:
                NotificationCenter.default.post(name: .moduleAdded, object: nil)
                Logger.shared.log("Successfully added module from URL scheme: \(moduleURL)")
            case .failure(let error):
                Logger.shared.log("Failed to add module from URL scheme: \(error.localizedDescription)")
            }
        }
    }
}
