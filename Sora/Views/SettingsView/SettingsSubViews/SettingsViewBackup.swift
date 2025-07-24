//
//  SettingsViewBackup.swift
//  Sora
//
//  Created by paul on 29/06/25.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers

fileprivate struct SettingsSection<Content: View>: View {
    let title: String
    let footer: String?
    let content: Content
    
    init(title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.footnote)
                .foregroundStyle(.gray)
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                content
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.accentColor.opacity(0.3), location: 0),
                                .init(color: Color.accentColor.opacity(0), location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .padding(.horizontal, 20)
            
            if let footer = footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
        }
    }
}

fileprivate struct SettingsActionRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    var showDivider: Bool = true
    var color: Color = .accentColor
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(color)
                Text(title)
                    .foregroundStyle(color)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color.clear)
        .contentShape(Rectangle())
        .overlay(
            VStack {
                if showDivider {
                    Divider().padding(.leading, 56)
                }
            }, alignment: .bottom
        )
    }
}

fileprivate struct BackupCoverageItem: View {
    let icon: String
    let title: String
    let isIncluded: Bool
    var showDivider: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
                .foregroundStyle(isIncluded ? Color.green : Color.red)
            
            Text(title)
                .foregroundStyle(Color.primary)
            
            Spacer()
            
            Image(systemName: isIncluded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isIncluded ? Color.green : Color.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

fileprivate struct BackupCoverageView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(NSLocalizedString("Included", comment: "Title for items included in backup"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 16)
            
            BackupCoverageItem(icon: "film", title: NSLocalizedString("Continue Watching", comment: "Continue watching backup item"), isIncluded: true, showDivider: false)
            BackupCoverageItem(icon: "book", title: NSLocalizedString("Continue Reading", comment: "Continue reading backup item"), isIncluded: true, showDivider: false)
            BackupCoverageItem(icon: "bookmark.fill", title: NSLocalizedString("Collections & Bookmarks", comment: "Collections backup item"), isIncluded: true, showDivider: false)
            BackupCoverageItem(icon: "magnifyingglass", title: NSLocalizedString("Search History", comment: "Search history backup item"), isIncluded: true, showDivider: false)
            BackupCoverageItem(icon: "puzzlepiece.fill", title: NSLocalizedString("Modules", comment: "Modules backup item"), isIncluded: true, showDivider: false)
            
            HStack {
                Text(NSLocalizedString("Not Included", comment: "Title for items not included in backup"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 16)
            
            BackupCoverageItem(icon: "arrow.down.circle", title: NSLocalizedString("Downloaded Files", comment: "Downloads backup item"), isIncluded: false, showDivider: false)
            BackupCoverageItem(icon: "gearshape", title: NSLocalizedString("App Settings", comment: "App settings backup item"), isIncluded: false, showDivider: false)
            BackupCoverageItem(icon: "person.crop.circle", title: NSLocalizedString("Account Logins", comment: "Account logins backup item"), isIncluded: false, showDivider: false)
        }
    }
}

struct SettingsViewBackup: View {
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportURL: URL?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var exportData: Data? = nil
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                SettingsSection(
                    title: NSLocalizedString("Backup & Restore", comment: "Settings section title for backup and restore"),
                    footer: nil
                ) {
                    SettingsActionRow(
                        icon: "arrow.up.doc",
                        title: NSLocalizedString("Export Backup", comment: "Export backup button title"),
                        action: {
                            exportData = generateBackupData()
                            showExporter = true
                        },
                        showDivider: true
                    )
                    SettingsActionRow(
                        icon: "arrow.down.doc",
                        title: NSLocalizedString("Import Backup", comment: "Import backup button title"),
                        action: {
                            showImporter = true
                        },
                        showDivider: false
                    )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("Backup Coverage", comment: "Settings section title for backup coverage details"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 2)
                    BackupCoverageView()
                }
                
                Text(NSLocalizedString("Notice: This feature is still experimental. Please double-check your data after import/export. \nAlso note that when importing a backup your current data will be overwritten, it is not possible to merge yet.", comment: "Footer notice for experimental backup/restore feature"))
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }
            .scrollViewBottomPadding()
            .padding(.bottom, 20)
            .padding(.top, 20)
        }
        .navigationTitle(NSLocalizedString("Backup & Restore", comment: "Navigation title for backup and restore view"))
        .fileExporter(
            isPresented: $showExporter,
            document: BackupDocument(data: exportData ?? Data()),
            contentType: .json,
            defaultFilename: exportFilename()
        ) { result in
            switch result {
            case .success(let url):
                alertMessage = "Exported to \(url.lastPathComponent)"
                showAlert = true
            case .failure(let error):
                alertMessage = "Export failed: \(error.localizedDescription)"
                showAlert = true
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                var success = false
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    do {
                        let data = try Data(contentsOf: url)
                        try restoreBackupData(data)
                        alertMessage = "Import successful!"
                        success = true
                    } catch {
                        alertMessage = "Import failed: \(error.localizedDescription)"
                    }
                }
                if !success {
                    alertMessage = "Import failed: Could not access file."
                }
                showAlert = true
            case .failure(let error):
                alertMessage = "Import failed: \(error.localizedDescription)"
                showAlert = true
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(NSLocalizedString("Backup", comment: "Alert title for backup actions")), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    @MainActor
    private func generateBackupData() -> Data? {
        let continueWatching = ContinueWatchingManager.shared.fetchItems()
        let continueReading = ContinueReadingManager.shared.fetchItems()
        let collections = (try? JSONDecoder().decode([BookmarkCollection].self, from: UserDefaults.standard.data(forKey: "bookmarkCollections") ?? Data())) ?? []
        let searchHistory = UserDefaults.standard.stringArray(forKey: "searchHistory") ?? []
        let modules = ModuleManager().modules 

        let backup: [String: Any] = [
            "continueWatching": continueWatching.map { try? $0.toDictionary() },
            "continueReading": continueReading.map { try? $0.toDictionary() },
            "collections": collections.map { try? $0.toDictionary() },
            "searchHistory": searchHistory,
            "modules": modules.map { try? $0.toDictionary() }
        ]
        
        return try? JSONSerialization.data(withJSONObject: backup, options: .prettyPrinted)
    }
    
    private func restoreBackupData(_ data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw NSError(domain: "restoreBackupData", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid backup format"])
        }
        if let cwArr = json["continueWatching"] as? NSArray {
            let cwData = try JSONSerialization.data(withJSONObject: cwArr, options: [])
            UserDefaults.standard.set(cwData, forKey: "continueWatchingItems")
        }
        if let crArr = json["continueReading"] as? NSArray {
            let crData = try JSONSerialization.data(withJSONObject: crArr, options: [])
            UserDefaults.standard.set(crData, forKey: "continueReadingItems")
        }
        if let colArr = json["collections"] as? NSArray {
            let colData = try JSONSerialization.data(withJSONObject: colArr, options: [])
            UserDefaults.standard.set(colData, forKey: "bookmarkCollections")
        }
        if let shArr = json["searchHistory"] as? [String] {
            UserDefaults.standard.set(shArr, forKey: "searchHistory")
        }
        if let modArr = json["modules"] as? NSArray {
            let modData = try JSONSerialization.data(withJSONObject: modArr, options: [])
            let fileManager = FileManager.default
            let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let modulesURL = docs.appendingPathComponent("modules.json")
            try modData.write(to: modulesURL)
        }
        UserDefaults.standard.synchronize()
    }
    
    
    private func exportFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = formatter.string(from: Date())
        return "SoraBackup_\(dateString).json"
    }
}


extension Encodable {
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = json as? [String: Any] else {
            throw NSError(domain: "toDictionary", code: 0, userInfo: nil)
        }
        return dict
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return .init(regularFileWithContents: data)
    }
} 
