//
//  SettingsViewData.swift
//  Sora
//
//  Created by Francesco on 05/02/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsViewData: View {
    @State private var showEraseAppDataAlert = false
    @State private var showRemoveDocumentsAlert = false
    @State private var showSizeAlert = false
    @State private var cacheSizeText: String = "Calculating..."
    @State private var isCalculatingSize: Bool = false
    @State private var cacheSize: Int64 = 0
    @State private var documentsSize: Int64 = 0
    @State private var movPkgSize: Int64 = 0
    @State private var showRemoveMovPkgAlert = false
    
    @State private var isMetadataCachingEnabled: Bool = true
    @State private var isImageCachingEnabled: Bool = true
    @State private var isMemoryOnlyMode: Bool = false
    
    @StateObject private var backupManager = BackupManager.shared
    @State private var showingExportSuccess = false
    @State private var showingImportSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingFilePicker = false
    @State private var showingShareSheet = false
    @State private var backupURL: URL?
    
    var body: some View {
        Form {
            Section(header: Text("Backup & Restore"), footer: Text("Create backups to transfer your data to another device or restore from a previous backup.")) {
                Button(action: exportBackup) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                        Text("Create Backup")
                        Spacer()
                    }
                }
                
                Button(action: { showingFilePicker = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.green)
                        Text("Restore from Backup")
                        Spacer()
                    }
                }
            }
            
            Section(header: Text("Cache Settings"), footer: Text("Caching helps reduce network usage and load content faster. You can disable it to save storage space.")) {
                Toggle("Enable Metadata Caching", isOn: $isMetadataCachingEnabled)
                    .onChange(of: isMetadataCachingEnabled) { newValue in
                        MetadataCacheManager.shared.isCachingEnabled = newValue
                        if !newValue {
                            calculateCacheSize()
                        }
                    }
                
                Toggle("Enable Image Caching", isOn: $isImageCachingEnabled)
                    .onChange(of: isImageCachingEnabled) { newValue in
                        KingfisherCacheManager.shared.isCachingEnabled = newValue
                        if !newValue {
                            calculateCacheSize()
                        }
                    }
                
                if isMetadataCachingEnabled {
                    Toggle("Memory-Only Mode", isOn: $isMemoryOnlyMode)
                        .onChange(of: isMemoryOnlyMode) { newValue in
                            MetadataCacheManager.shared.isMemoryOnlyMode = newValue
                            if newValue {
                                MetadataCacheManager.shared.clearAllCache()
                                calculateCacheSize()
                            }
                        }
                }
                
                HStack {
                    Text("Current Cache Size")
                    Spacer()
                    if isCalculatingSize {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(.trailing, 5)
                    }
                    Text(cacheSizeText)
                        .foregroundColor(.secondary)
                }
                
                Button(action: clearAllCaches) {
                    Text("Clear All Caches")
                        .foregroundColor(.red)
                }
            }
            
            Section(header: Text("App storage"), footer: Text("The caches used by Sora are stored images that help load content faster\n\nThe App Data should never be erased if you dont know what that will cause.\n\nClearing the documents folder will remove all the modules and downloads")) {
                HStack {
                    Button(action: clearCache) {
                        Text("Clear Cache")
                    }
                    Spacer()
                    Text("\(formatSize(cacheSize))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Button(action: {
                        showRemoveDocumentsAlert = true
                    }) {
                        Text("Remove All Files in Documents")
                    }
                    Spacer()
                    Text("\(formatSize(documentsSize))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Button(action: {
                        showRemoveMovPkgAlert = true
                    }) {
                        Text("Remove Downloads")
                    }
                    Spacer()
                    Text("\(formatSize(movPkgSize))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    showEraseAppDataAlert = true
                }) {
                    Text("Erase all App Data")
                }
            }
        }
        .navigationTitle("App Data")
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            isMetadataCachingEnabled = MetadataCacheManager.shared.isCachingEnabled
            isImageCachingEnabled = KingfisherCacheManager.shared.isCachingEnabled
            isMemoryOnlyMode = MetadataCacheManager.shared.isMemoryOnlyMode
            calculateCacheSize()
            updateSizes()
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = backupURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Backup Created", isPresented: $showingExportSuccess) {
            Button("Share") {
                showingShareSheet = true
            }
            Button("OK") { }
        } message: {
            Text("Your backup has been created successfully. You can share it or find it in your Files app.")
        }
        .alert("Backup Restored", isPresented: $showingImportSuccess) {
            Button("OK") { }
        } message: {
            Text("Your data has been restored successfully. The app will refresh with your restored settings.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert(isPresented: $showEraseAppDataAlert) {
            Alert(
                title: Text("Erase App Data"),
                message: Text("Are you sure you want to erase all app data? This action cannot be undone."),
                primaryButton: .destructive(Text("Erase")) {
                    eraseAppData()
                },
                secondaryButton: .cancel()
            )
        }
        .alert(isPresented: $showRemoveDocumentsAlert) {
            Alert(
                title: Text("Remove Documents"),
                message: Text("Are you sure you want to remove all files in the Documents folder? This will remove all modules."),
                primaryButton: .destructive(Text("Remove")) {
                    removeAllFilesInDocuments()
                },
                secondaryButton: .cancel()
            )
        }
        .alert(isPresented: $showRemoveMovPkgAlert) {
            Alert(
                title: Text("Remove Downloads"),
                message: Text("Are you sure you want to remove all Downloads?"),
                primaryButton: .destructive(Text("Remove")) {
                    removeMovPkgFiles()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func exportBackup() {
        guard let url = backupManager.exportBackup() else {
            errorMessage = "Failed to create backup file"
            showingError = true
            return
        }
        
        backupURL = url
        showingExportSuccess = true
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            if backupManager.importBackup(from: url) {
                showingImportSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isMetadataCachingEnabled = MetadataCacheManager.shared.isCachingEnabled
                    isImageCachingEnabled = KingfisherCacheManager.shared.isCachingEnabled
                    isMemoryOnlyMode = MetadataCacheManager.shared.isMemoryOnlyMode
                }
            } else {
                errorMessage = "Failed to restore backup. Please check if the file is a valid Sora backup."
                showingError = true
            }
            
        case .failure(let error):
            errorMessage = "Failed to read backup file: \(error.localizedDescription)"
            showingError = true
        }
    }
    func calculateCacheSize() {
        isCalculatingSize = true
        cacheSizeText = "Calculating..."
        
        DispatchQueue.global(qos: .background).async {
            var totalSize: Int64 = 0
            let metadataSize = MetadataCacheManager.shared.getCacheSize()
            totalSize += metadataSize
            
            KingfisherCacheManager.shared.calculateCacheSize { imageSize in
                totalSize += Int64(imageSize)
                
                DispatchQueue.main.async {
                    self.cacheSizeText = KingfisherCacheManager.formatCacheSize(UInt(totalSize))
                    self.isCalculatingSize = false
                }
            }
        }
    }
    
    func clearAllCaches() {
        MetadataCacheManager.shared.clearAllCache()
        KingfisherCacheManager.shared.clearCache {
            calculateCacheSize()
        }
        
        Logger.shared.log("All caches cleared", type: "General")
    }
    
    func eraseAppData() {
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
            UserDefaults.standard.synchronize()
            Logger.shared.log("Cleared app data!", type: "General")
            exit(0)
        }
    }
    
    func clearCache() {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        
        do {
            if let cacheURL = cacheURL {
                let filePaths = try FileManager.default.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil, options: [])
                for filePath in filePaths {
                    try FileManager.default.removeItem(at: filePath)
                }
                Logger.shared.log("Cache cleared successfully!", type: "General")
                calculateCacheSize()
                updateSizes()
            }
        } catch {
            Logger.shared.log("Failed to clear cache.", type: "Error")
        }
    }
    
    func removeAllFilesInDocuments() {
        let fileManager = FileManager.default
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
                for fileURL in fileURLs {
                    try fileManager.removeItem(at: fileURL)
                }
                Logger.shared.log("All files in documents folder removed", type: "General")
                exit(0)
            } catch {
                Logger.shared.log("Error removing files in documents folder: \(error)", type: "Error")
            }
        }
    }
    
    func removeMovPkgFiles() {
        let fileManager = FileManager.default
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
                for fileURL in fileURLs {
                    if fileURL.pathExtension == "movpkg" {
                        try fileManager.removeItem(at: fileURL)
                    }
                }
                Logger.shared.log("All Downloads files removed", type: "General")
                updateSizes()
            } catch {
                Logger.shared.log("Error removing Downloads files: \(error)", type: "Error")
            }
        }
    }
    
    private func calculateDirectorySize(for url: URL) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])
            for url in contents {
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                if resourceValues.isDirectory == true {
                    totalSize += calculateDirectorySize(for: url)
                } else {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            }
        } catch {
            Logger.shared.log("Error calculating directory size: \(error)", type: "Error")
        }
        
        return totalSize
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func updateSizes() {
        if let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            cacheSize = calculateDirectorySize(for: cacheURL)
        }
        
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            documentsSize = calculateDirectorySize(for: documentsURL)
            movPkgSize = calculateMovPkgSize(in: documentsURL)
        }
    }
    
    private func calculateMovPkgSize(in url: URL) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])
            for url in contents where url.pathExtension == "movpkg" {
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        } catch {
            Logger.shared.log("Error calculating MovPkg size: \(error)", type: "Error")
        }
        
        return totalSize
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
