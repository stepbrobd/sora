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
    @StateObject private var librarykManager = LibraryManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(moduleManager)
                .environmentObject(settings)
                .environmentObject(librarykManager)
                .accentColor(settings.accentColor)
                .onAppear {
                    settings.updateAppearance()
                    if UserDefaults.standard.bool(forKey: "refreshModulesOnLaunch") {
                        Task {
                            await moduleManager.refreshModules()
                        }
                    }
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
        
        let addModuleView = ModuleAdditionSettingsView(moduleUrl: moduleURL).environmentObject(moduleManager)
        let hostingController = UIHostingController(rootView: addModuleView)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(hostingController, animated: true)
        } else {
            Logger.shared.log("Failed to present module addition view: No window scene found", type: "Error")
        }
    }
}
