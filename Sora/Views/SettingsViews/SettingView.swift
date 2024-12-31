//
//  SettingView.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI
import Kingfisher
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    @State private var isDocumentPickerPresented = false
    @State private var showImportSuccessAlert = false
    @State private var showImportFailAlert = false
    @State private var importErrorMessage = ""
    @State private var miruDataToImport: MiruDataStruct?
    @State private var selectedModule: ModuleStruct?
    @StateObject private var libraryManager = LibraryManager.shared
    @StateObject private var modulesManager = ModulesManager()

    var body: some View {
        NavigationView {
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
                    NavigationLink(destination: SettingsIUView()) {
                        Text("Interface Settings")
                    }
                    NavigationLink(destination: SettingsPlayerView()) {
                        Text("Media Player")
                    }
                }
                
                Section(header: Text("External Features")) {
                    NavigationLink(destination: SettingsModuleView()) {
                        HStack {
                            Image(systemName: "puzzlepiece.fill")
                            Text("Modules")
                        }
                    }
                    NavigationLink(destination: SettingsStorageView()) {
                        HStack {
                            Image(systemName: "externaldrive.fill")
                            Text("Storage")
                        }
                    }
                    ForEach(modulesManager.modules.filter { $0.extractor == "dub-sub" }, id: \.name) { module in
                        Button(action: {
                            isDocumentPickerPresented = true
                            selectedModule = module
                        }) {
                            HStack {
                                Image(systemName: "tray.and.arrow.down.fill")
                                Text("Import Miru Bookmarks into \(module.name)")
                            }
                        }
                    }
                }
                
                Section(header: Text("Debug")) {
                    NavigationLink(destination: SettingsLogsView()) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                            Text("Logs")
                        }
                    }
                }
                
                Section(header: Text("Info")) {
                    NavigationLink(destination: AboutView()) {
                        Text("About")
                    }
                    NavigationLink(destination: SettingsReleasesView()) {
                        Text("Releases")
                    }
                    Button(action: {
                        if let url = URL(string: "https://github.com/cranci1/Sora") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("Sora github repo")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "safari")
                                .foregroundColor(.secondary)
                        }
                    }
                    Button(action: {
                        if let url = URL(string: "https://github.com/cranci1/Sora/issues") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("Report an issue")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "safari")
                                .foregroundColor(.secondary)
                        }
                    }
                    Button(action: {
                        if let url = URL(string: "https://discord.gg/x7hppDWFDZ") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("Join the Discord")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "safari")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $isDocumentPickerPresented) {
                DocumentPicker(
                    libraryManager: libraryManager,
                    onSuccess: { miruData in
                        miruDataToImport = miruData
                        if let selectedModule = selectedModule {
                            libraryManager.importFromMiruData(miruData, module: selectedModule)
                            showImportSuccessAlert = true
                        }
                    },
                    onFailure: { errorMessage in
                        importErrorMessage = errorMessage
                        showImportFailAlert = true
                    }
                )
            }
            .alert("Data Imported!", isPresented: $showImportSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Miru bookmarks are now imported in Sora, enjoy!")
            }
            .alert("Import Failed", isPresented: $showImportFailAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importErrorMessage)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    var libraryManager: LibraryManager
    var onSuccess: (MiruDataStruct) -> Void
    var onFailure: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, libraryManager: libraryManager, onSuccess: onSuccess, onFailure: onFailure)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        var libraryManager: LibraryManager
        var onSuccess: (MiruDataStruct) -> Void
        var onFailure: (String) -> Void
        
        init(_ parent: DocumentPicker, libraryManager: LibraryManager, onSuccess: @escaping (MiruDataStruct) -> Void, onFailure: @escaping (String) -> Void) {
            self.parent = parent
            self.libraryManager = libraryManager
            self.onSuccess = onSuccess
            self.onFailure = onFailure
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let selectedFileURL = urls.first else {
                let errorMessage = "No file URL selected"
                print(errorMessage)
                Logger.shared.log(errorMessage)
                onFailure(errorMessage)
                return
            }
            
            guard selectedFileURL.startAccessingSecurityScopedResource() else {
                let errorMessage = "Could not access the file"
                print(errorMessage)
                Logger.shared.log("Could not access the Miru Backup File")
                onFailure(errorMessage)
                return
            }
            
            defer {
                selectedFileURL.stopAccessingSecurityScopedResource()
            }
            
            do {
                let data = try Data(contentsOf: selectedFileURL)
                var miruData = try JSONDecoder().decode(MiruDataStruct.self, from: data)
                
                miruData.likes = miruData.likes.map { like in
                    var updatedLike = like
                    updatedLike.gogoSlug = "/series/" + like.gogoSlug
                    return updatedLike
                }
                
                Logger.shared.log("Imported Miru data from \(selectedFileURL)")
                onSuccess(miruData)
            } catch {
                let errorMessage = "Failed to import Miru data: \(error.localizedDescription)"
                print(errorMessage)
                Logger.shared.log(errorMessage)
                onFailure(errorMessage)
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            let errorMessage = "Document picker was closed"
            print(errorMessage)
            Logger.shared.log(errorMessage)
            onFailure(errorMessage)
        }
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    
    var id: String { self.rawValue }
}

class Settings: ObservableObject {
    @Published var accentColor: Color {
        didSet {
            saveAccentColor(accentColor)
        }
    }
    @Published var selectedAppearance: Appearance {
        didSet {
            UserDefaults.standard.set(selectedAppearance.rawValue, forKey: "selectedAppearance")
            updateAppearance()
        }
    }
    
    init() {
        if let colorData = UserDefaults.standard.data(forKey: "accentColor"),
           let uiColor = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(colorData) as? UIColor {
            self.accentColor = Color(uiColor)
        } else {
            self.accentColor = .accentColor
        }
        if let appearanceRawValue = UserDefaults.standard.string(forKey: "selectedAppearance"),
           let appearance = Appearance(rawValue: appearanceRawValue) {
            self.selectedAppearance = appearance
        } else {
            self.selectedAppearance = .system
        }
        updateAppearance()
    }
    
    private func saveAccentColor(_ color: Color) {
        let uiColor = UIColor(color)
        do {
            let colorData = try NSKeyedArchiver.archivedData(withRootObject: uiColor, requiringSecureCoding: false)
            UserDefaults.standard.set(colorData, forKey: "accentColor")
        } catch {
            print("Failed to save accent color: \(error.localizedDescription)")
            Logger.shared.log("Failed to save accent color: \(error.localizedDescription)")
        }
    }
    
    func updateAppearance() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        switch selectedAppearance {
        case .system:
            windowScene.windows.first?.overrideUserInterfaceStyle = .unspecified
        case .light:
            windowScene.windows.first?.overrideUserInterfaceStyle = .light
        case .dark:
            windowScene.windows.first?.overrideUserInterfaceStyle = .dark
        }
    }
}
