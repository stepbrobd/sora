//
//  SettingsModuleView.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI
import Kingfisher

struct ErrorMessage: Identifiable {
    var id: String { message }
    let message: String
}

struct SettingsModuleView: View {
    @StateObject private var modulesManager = ModulesManager()
    @State private var showingAddModuleAlert = false
    @State private var moduleURL = ""
    @State private var errorMessage: ErrorMessage?
    @State private var previusImageURLs: [String: String] = [:]
    
    var body: some View {
        VStack {
            if modulesManager.isLoading {
                ProgressView("Loading Modules...")
            } else {
                List {
                    ForEach(modulesManager.modules, id: \.name) { module in
                        HStack {
                            if let url = URL(string: module.iconURL) {
                                if previusImageURLs[module.name] != module.iconURL {
                                    KFImage(url)
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                        .padding(.trailing, 10)
                                        .onAppear {
                                            previusImageURLs[module.name] = module.iconURL
                                        }
                                } else {
                                    KFImage(url)
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                        .padding(.trailing, 10)
                                }
                            }
                            VStack(alignment: .leading) {
                                Text(module.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Version: \(module.version)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Author: \(module.author.name)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Language: \(module.language)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(module.stream)
                                .font(.caption)
                                .padding(5)
                                .background(Color.accentColor)
                                .foregroundColor(Color.primary)
                                .clipShape(Capsule())
                        }
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.string = modulesManager.moduleURLs[module.name]
                            }) {
                                Label("Copy URL", systemImage: "doc.on.doc")
                            }
                            Button(role: .destructive, action: {
                                modulesManager.deleteModule(named: module.name)
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deleteModule)
                }
                .navigationBarTitle("Modules")
                .navigationBarItems(trailing: Button(action: {
                    showAddModuleAlert()
                }) {
                    Image(systemName: "plus")
                        .resizable()
                        .frame(width: 20, height: 20)
                })
                .refreshable {
                    modulesManager.refreshModules()
                }
            }
        }
        .onAppear {
            modulesManager.loadModules()
        }
        .alert(item: $errorMessage) { error in
            Alert(title: Text("Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
    }
    
    func showAddModuleAlert() {
        let alert = UIAlertController(title: "Add Module", message: "Enter the URL of the module file", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "https://cranci.tech/sora/animeworld.json"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { _ in
            if let url = alert.textFields?.first?.text {
                modulesManager.addModule(from: url) { result in
                    switch result {
                    case .success:
                        break
                    case .failure(let error):
                        errorMessage = ErrorMessage(message: error.localizedDescription)
                        Logger.shared.log(error.localizedDescription.capitalized)
                    }
                }
            }
        }))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true, completion: nil)
        }
    }
    
    func deleteModule(at offsets: IndexSet) {
        offsets.forEach { index in
            let module = modulesManager.modules[index]
            modulesManager.deleteModule(named: module.name)
        }
    }
}
