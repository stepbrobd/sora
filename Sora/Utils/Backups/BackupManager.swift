//
//  BackupManager.swift
//  Sulfur
//
//  Created by Francesco on 25/05/25.
//

import Foundation

class BackupManager: ObservableObject {
    static let shared = BackupManager()
    
    private init() {}
    
    func createBackup() -> BackupData {
        var userData: [String: Any] = [:]
        
        let userDefaults = UserDefaults.standard
        let defaultsDict = userDefaults.dictionaryRepresentation()
        
        let appKeys = defaultsDict.keys.filter { key in
            !key.hasPrefix("Apple") &&
            !key.hasPrefix("NS") &&
            !key.hasPrefix("com.apple") &&
            !key.contains("Keyboard")
        }
        
        for key in appKeys {
            userData[key] = defaultsDict[key]
        }
        
        return BackupData(userData: userData)
    }
    
    func exportBackup() -> URL? {
        let backup = createBackup()
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(backup)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "sora_backup_\(DateFormatter.backupFormatter.string(from: Date())).json"
            let fileURL = documentsPath.appendingPathComponent(fileName)
            
            try data.write(to: fileURL)
            return fileURL
            
        } catch {
            print("Failed to export backup: \(error)")
            return nil
        }
    }
    
    func importBackup(from url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let backup = try decoder.decode(BackupData.self, from: data)
            
            let userDefaults = UserDefaults.standard
            for (key, value) in backup.userData {
                userDefaults.set(value, forKey: key)
            }
            
            userDefaults.synchronize()
            
            
            NotificationCenter.default.post(name: .backupRestored, object: nil)
            
            return true
            
        } catch {
            print("Failed to import backup: \(error)")
            return false
        }
    }
    
    func shareBackup() -> URL? {
        return exportBackup()
    }
}

