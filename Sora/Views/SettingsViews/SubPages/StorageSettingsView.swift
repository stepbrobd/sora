//
//  StorageSettingsView.swift
//  Sora
//
//  Created by Francesco on 19/12/24.
//

import SwiftUI

struct StorageSettingsView: View {
    @State private var appSize: String = "Calculating..."
    @State private var storageDetails: [(String, Double, Color)] = []
    @State private var deviceStorage: (total: Int64, used: Int64) = (0, 0)
    @State private var showingClearCacheAlert = false
    @State private var showingClearDocumentsAlert = false
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        Text(appSize)
                            .font(.system(size: 28, weight: .bold))
                        Text("of \(ByteCountFormatter.string(fromByteCount: deviceStorage.total, countStyle: .file))")
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 24)
                                
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: geometry.size.width * CGFloat(deviceStorage.used) / CGFloat(deviceStorage.total))
                                    .frame(height: 24)
                                
                                HStack(spacing: 0) {
                                    ForEach(storageDetails, id: \.0) { detail in
                                        RoundedRectangle(cornerRadius: 0)
                                            .fill(detail.2)
                                            .frame(width: geometry.size.width * CGFloat(detail.1 * 1024 * 1024) / CGFloat(deviceStorage.total))
                                    }
                                }
                                .frame(height: 24)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .frame(height: 24)
                        
                        HStack(spacing: 16) {
                            ForEach(storageDetails, id: \.0) { detail in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(detail.2)
                                        .frame(width: 8, height: 8)
                                    Text(detail.0)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                Text("System")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section {
                ForEach(storageDetails, id: \.0) { detail in
                    HStack {
                        Image(systemName: categoryIcon(for: detail.0))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(detail.2)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(detail.0)
                            Text("\(detail.1, specifier: "%.2f") MB")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section(header: Text("Actions")) {
                Button(action: { showingClearCacheAlert = true }) {
                    actionRow(
                        icon: "clock.fill",
                        title: "Clear Cache",
                        subtitle: "Free up space used by cached items",
                        iconColor: .accentColor
                    )
                }
                
                Button(action: { showingClearDocumentsAlert = true }) {
                    actionRow(
                        icon: "doc.fill",
                        title: "Clear Documents",
                        subtitle: "Check and remove unnecessary files",
                        iconColor: .accentColor
                    )
                }
            }
        }
        .navigationTitle("Storage")
        .onAppear {
            calculateAppSize()
            getDeviceStorage()
        }
        .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("Are you sure you want to clear the cache? This action cannot be undone.")
        }
        .alert("Clear Documents", isPresented: $showingClearDocumentsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearDocuments()
            }
        } message: {
            Text("Are you sure you want to clear all documents? This action cannot be undone.")
        }
    }
    
    private func clearCache() {
        if let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: cacheURL,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )
                
                for fileURL in fileURLs {
                    try FileManager.default.removeItem(at: fileURL)
                }
                
                calculateAppSize()
                getDeviceStorage()
                Logger.shared.log("Cleared Cache")
            } catch {
                print("Error clearing cache: \(error)")
                Logger.shared.log("Error clearing cache: \(error)")
            }
        }
    }
    
    private func clearDocuments() {
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: documentsURL,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )
                
                for fileURL in fileURLs {
                    try FileManager.default.removeItem(at: fileURL)
                }
                
                calculateAppSize()
                getDeviceStorage()
                Logger.shared.log("Cleared Documents")
            } catch {
                print("Error clearing documents: \(error)")
                Logger.shared.log("Error clearing documents: \(error)")
            }
        }
    }
    
    private func getDeviceStorage() {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            
            if let total = values.volumeTotalCapacity,
               let available = values.volumeAvailableCapacity {
                deviceStorage.total = Int64(total)
                deviceStorage.used = Int64(total - available)
            }
        } catch {
            print("Error getting device storage: \(error)")
            Logger.shared.log("Error getting device storage: \(error)")
        }
    }
    
    private func getTotalAppBytes() -> Int64 {
        return Int64(totalSize() * 1024 * 1024)
    }
    
    private func actionRow(icon: String, title: String, subtitle: String, iconColor: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Documents":
            return "doc.fill"
        case "Cache":
            return "clock.fill"
        case "Temporary":
            return "trash.fill"
        default:
            return "questionmark"
        }
    }
    
    private func calculateAppSize() {
        let cacheSize = getDirectorySize(url: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!)
        let documentsSize = getDirectorySize(url: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!)
        let tmpSize = getDirectorySize(url: FileManager.default.temporaryDirectory)
        
        let totalSize = cacheSize + documentsSize + tmpSize
        self.appSize = ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
        self.storageDetails = [
            ("Documents", documentsSize / 1024 / 1024, .green),
            ("Cache", cacheSize / 1024 / 1024, .orange),
            ("Temporary", tmpSize / 1024 / 1024, .red)
        ]
    }
    
    private func getDirectorySize(url: URL) -> Double {
        var size: Double = 0
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [], errorHandler: nil) {
            for case let fileURL as URL in enumerator {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    size += Double(resourceValues.fileSize ?? 0)
                } catch {
                    print("Error calculating size for file \(fileURL): \(error)")
                    Logger.shared.log("Error calculating size for file \(fileURL): \(error)")
                }
            }
        }
        return size
    }
    
    private func totalSize() -> Double {
        return storageDetails.reduce(0) { $0 + $1.1 }
    }
}
