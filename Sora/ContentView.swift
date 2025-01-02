//
//  ContentView.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var modulesManager: ModulesManager
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .onAppear {
            checkForUpdate()
            Logger.shared.log("Started Sora")
        }
    }
    
    func checkForUpdate() {
        fetchLatestRelease { release in
            guard let release = release else { return }
            
            let latestVersion = release.tagName
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.1"
            
            if latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                DispatchQueue.main.async {
                    showUpdateAlert(release: release)
                }
            }
        }
    }
    
    func fetchLatestRelease(completion: @escaping (GitHubRelease?) -> Void) {
        let url = URL(string: "https://api.github.com/repos/cranci1/Sora/releases/latest")!
        
        URLSession.custom.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            let release = try? JSONDecoder().decode(GitHubRelease.self, from: data)
            completion(release)
        }.resume()
    }
    
    func showUpdateAlert(release: GitHubRelease) {
        let alert = UIAlertController(title: "Update Available", message: "A new version (\(release.tagName)) is available. Would you like to update Sora?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Update", style: .default, handler: { _ in
            self.showInstallOptionsAlert(release: release)
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true, completion: nil)
        }
    }
    
    func showInstallOptionsAlert(release: GitHubRelease) {
        let installAlert = UIAlertController(title: "Install Update", message: "Choose an installation method:", preferredStyle: .alert)
        
        let downloadUrl = release.assets.first?.browserDownloadUrl ?? ""
        
        installAlert.addAction(UIAlertAction(title: "Install in AltStore", style: .default, handler: { _ in
            if let url = URL(string: "altstore://install?url=\(downloadUrl)") {
                UIApplication.shared.open(url)
            }
        }))
        
        installAlert.addAction(UIAlertAction(title: "Install in Sidestore", style: .default, handler: { _ in
            if let url = URL(string: "sidestore://install?url=\(downloadUrl)") {
                UIApplication.shared.open(url)
            }
        }))
        
        installAlert.addAction(UIAlertAction(title: "Open in Safari", style: .default, handler: { _ in
            if let url = URL(string: downloadUrl) {
                UIApplication.shared.open(url)
            }
        }))
        
        installAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(installAlert, animated: true, completion: nil)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
