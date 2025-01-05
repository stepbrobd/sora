//
//  Settings.swift
//  Sora-JS
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var moduleManager: ModuleManager
    @AppStorage("selectedModuleId") private var selectedModuleId: String?
    @State private var showingAddModule = false
    @State private var newModuleUrl = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        List {
            ForEach(moduleManager.modules) { module in
                ModuleRow(module: module, isSelected: module.id.uuidString == selectedModuleId)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedModuleId = module.id.uuidString
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            if selectedModuleId == module.id.uuidString {
                                selectedModuleId = nil
                            }
                            moduleManager.deleteModule(module)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .navigationTitle("Scraping Modules")
        .toolbar {
            Button {
                showingAddModule = true
            } label: {
                Label("Add Module", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingAddModule) {
            NavigationView {
                Form {
                    Section(header: Text("New Module")) {
                        TextField("Module JSON URL", text: $newModuleUrl)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                    }
                    
                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                }
                .navigationTitle("Add Module")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showingAddModule = false
                    },
                    trailing: Button("Add") {
                        addModule()
                    }
                        .disabled(newModuleUrl.isEmpty || isLoading)
                )
            }
        }
    }
    
    private func addModule() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await moduleManager.addModule(metadataUrl: newModuleUrl)
                DispatchQueue.main.async {
                    isLoading = false
                    showingAddModule = false
                    newModuleUrl = ""
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct ModuleRow: View {
    let module: ScrapingModule
    let isSelected: Bool
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: module.metadata.iconUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Color.gray
            }
            .frame(width: 40, height: 40)
            .cornerRadius(8)
            
            VStack(alignment: .leading) {
                Text(module.metadata.mediaType)
                    .font(.headline)
                Text("by \(module.metadata.author)")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(module.metadata.language) • v\(module.metadata.version)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
    }
}
