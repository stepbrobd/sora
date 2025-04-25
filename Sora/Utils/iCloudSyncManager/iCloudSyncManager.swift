//
//  iCloudSyncManager.swift
//  Sulfur
//
//  Created by Francesco on 17/04/25.
//

import UIKit

class iCloudSyncManager {
    static let shared = iCloudSyncManager()
    
    let syncQueue = DispatchQueue(label: "me.cranci.sora.icloud-sync", qos: .utility)
    let retryAttempts = 3
    let retryDelay: TimeInterval = 2.0
    
    var isSyncing = false
    var lastSyncAttempt: Date?
    var syncErrors: Int = 0
    
    let defaultsToSync: [String] = [
        "externalPlayer",
        "alwaysLandscape",
        "rememberPlaySpeed",
        "holdSpeedPlayer",
        "skipIncrement",
        "skipIncrementHold",
        "holdForPauseEnabled",
        "skip85Visible",
        "doubleTapSeekEnabled",
        "selectedModuleId",
        "mediaColumnsPortrait",
        "mediaColumnsLandscape",
        "sendPushUpdates",
        "sendTraktUpdates",
        "bookmarkedItems",
        "continueWatchingItems",
        "analyticsEnabled",
        "refreshModulesOnLaunch",
        "fetchEpisodeMetadata",
        "multiThreads",
        "metadataProviders"
    ]
    
    var ubiquityContainerURL: URL? {
        get {
            let semaphore = DispatchSemaphore(value: 0)
            var containerURL: URL?
            
            DispatchQueue.global(qos: .userInitiated).async {
                containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
                semaphore.signal()
            }
            
            _ = semaphore.wait(timeout: .now() + 5.0)
            return containerURL
        }
    }
    
    private init() {
        setupSync()
    }
    
    private func setupSync() {
        guard FileManager.default.ubiquityIdentityToken != nil else {
            Logger.shared.log("iCloud is not available", type: "Error")
            return
        }
        
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.initializeICloudSync()
            } catch {
                Logger.shared.log("Failed to initialize iCloud sync: \(error.localizedDescription)", type: "Error")
            }
        }
        
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterBackground), name: UIApplication.willResignActiveNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(iCloudDidChangeExternally), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: NSUbiquitousKeyValueStore.default )
        
        NotificationCenter.default.addObserver( self, selector: #selector(userDefaultsDidChange), name: UserDefaults.didChangeNotification, object: nil)
    }
    
    func initializeICloudSync() throws {
        guard !isSyncing else { return }
        isSyncing = true
        
        defer { isSyncing = false }
        guard NSUbiquitousKeyValueStore.default.synchronize() else {
            throw NSError(domain: "iCloudSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize iCloud store"])
        }
        
        syncFromiCloud(retry: true)
        syncModulesFromiCloud()
    }
    
    func syncToiCloud(completion: ((Bool) -> Void)? = nil) {
        guard !isSyncing else {
            completion?(false)
            return
        }
        
        syncQueue.async { [weak self] in
            guard let self = self else {
                completion?(false)
                return
            }
            
            self.isSyncing = true
            var success = false
            
            defer {
                self.isSyncing = false
                DispatchQueue.main.async {
                    completion?(success)
                }
            }
            
            let container = NSUbiquitousKeyValueStore.default
            let defaults = UserDefaults.standard
            
            do {
                try self.performSync(from: defaults, to: container)
                success = container.synchronize()
                
                if success {
                    self.syncErrors = 0
                    Logger.shared.log("Successfully synced to iCloud", type: "Info")
                } else {
                    self.syncErrors += 1
                    throw NSError(
                        domain: "iCloudSync",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to synchronize with iCloud"]
                    )
                }
            } catch {
                Logger.shared.log("Sync to iCloud failed: \(error.localizedDescription)", type: "Error")
                
                if self.syncErrors < self.retryAttempts {
                    let delay = TimeInterval(pow(2.0, Double(self.syncErrors))) * self.retryDelay
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.syncToiCloud(completion: completion)
                    }
                }
            }
        }
    }
    
    private func performSync(from defaults: UserDefaults, to container: NSUbiquitousKeyValueStore) throws {
        var syncedKeys = 0
        let keysToSync = allKeysToSync()
        
        for key in keysToSync {
            guard let value = defaults.object(forKey: key) else { continue }
            
            do {
                if self.isValidValueType(value) {
                    if let arrayValue = value as? [Any] {
                        if !isValidPropertyListArray(arrayValue) {
                            Logger.shared.log("Skipping key \(key): contains invalid array elements", type: "Warning")
                            continue
                        }
                        _ = try JSONSerialization.data(withJSONObject: arrayValue)
                    } else if let dictValue = value as? [String: Any] {
                        if !isValidPropertyListDictionary(dictValue) {
                            Logger.shared.log("Skipping key \(key): contains invalid dictionary elements", type: "Warning")
                            continue
                        }
                        _ = try JSONSerialization.data(withJSONObject: dictValue)
                    }
                    
                    do {
                        container.set(value, forKey: key)
                        syncedKeys += 1
                    } catch {
                        Logger.shared.log("Failed to store key \(key) in iCloud: \(error.localizedDescription)", type: "Error")
                        continue
                    }
                }
            } catch {
                Logger.shared.log("Failed to sync key \(key): \(error.localizedDescription)", type: "Warning")
                continue
            }
        }
        
        Logger.shared.log("Synced \(syncedKeys) keys", type: "Info")
    }
    
    @objc private func iCloudDidChangeExternally(_ notification: NSNotification) {
        guard let iCloud = notification.object as? NSUbiquitousKeyValueStore,
              let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
                  Logger.shared.log("Invalid iCloud notification data", type: "Error")
                  return
              }
        
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            let defaults = UserDefaults.standard
            for key in changedKeys {
                if let value = iCloud.object(forKey: key), self.isValidValueType(value) {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
            
            defaults.synchronize()
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .iCloudSyncDidComplete, object: nil)
            }
        }
    }
    
    @objc private func userDefaultsDidChange(_ notification: Notification) {
        syncQueue.async { [weak self] in
            self?.syncToiCloud()
        }
    }
    
    func syncFromiCloud(retry: Bool = false) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            let iCloud = NSUbiquitousKeyValueStore.default
            let defaults = UserDefaults.standard
            
            var syncedKeys = 0
            var failedKeys = 0
            
            let keysToSync = self.allKeysToSync()
            
            for key in keysToSync {
                autoreleasepool {
                    if let value = iCloud.object(forKey: key) {
                        do {
                            if !key.isEmpty && self.isValidValueType(value) {
                                if JSONSerialization.isValidJSONObject(value) {
                                    _ = try JSONSerialization.data(withJSONObject: value)
                                    defaults.set(value, forKey: key)
                                    syncedKeys += 1
                                } else {
                                    Logger.shared.log("Invalid JSON value for key: \(key)", type: "Warning")
                                    defaults.removeObject(forKey: key)
                                    failedKeys += 1
                                }
                            } else {
                                Logger.shared.log("Invalid value type for key: \(key)", type: "Warning")
                                defaults.removeObject(forKey: key)
                                failedKeys += 1
                            }
                        } catch {
                            Logger.shared.log("JSON serialization failed for key: \(key) - \(error.localizedDescription)", type: "Error")
                            defaults.removeObject(forKey: key)
                            failedKeys += 1
                        }
                    }
                }
            }
            
            let success = defaults.synchronize()
            
            DispatchQueue.main.async { [weak self] in
                guard self != nil else { return }
                
                if !success || failedKeys > 0 {
                    let error = NSError(domain: "iCloudSync", code: -1, userInfo: [ NSLocalizedDescriptionKey: "Sync partially failed", "syncedKeys": syncedKeys, "failedKeys": failedKeys]
                    )
                    NotificationCenter.default.post(name: .iCloudSyncDidFail, object: error)
                    Logger.shared.log("Sync completed with errors: \(syncedKeys) succeeded, \(failedKeys) failed", type: "Warning")
                } else {
                    NotificationCenter.default.post(name: .iCloudSyncDidComplete, object: ["syncedKeys": syncedKeys])
                    Logger.shared.log("Successfully synced \(syncedKeys) keys from iCloud", type: "Info")
                }
            }
        }
    }
    
    private func isValidValueType(_ value: Any) -> Bool {
        return value is String ||
        value is Bool ||
        value is Int ||
        value is Float ||
        value is Double ||
        value is Data ||
        value is Date ||
        value is [Any] ||
        value is [String: Any]
    }
    
    @objc private func willEnterBackground() {
        syncQueue.async { [weak self] in
            self?.syncToiCloud()
            self?.syncModulesToiCloud()
        }
    }
    
    private func allProgressKeys() -> [String] {
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        let progressPrefixes = ["lastPlayedTime_", "totalTime_"]
        return allKeys.filter { key in
            progressPrefixes.contains { prefix in key.hasPrefix(prefix) }
        }
    }
    
    private func allKeysToSync() -> [String] {
        var keys = Set(defaultsToSync + allProgressKeys())
        let userDefaults = UserDefaults.standard
        let all = userDefaults.dictionaryRepresentation()
        for (key, value) in all {
            if key.hasPrefix("Apple") || key.hasPrefix("_") { continue }
            if value is Int || value is Double || value is Bool || value is String {
                keys.insert(key)
            }
        }
        return Array(keys)
    }
    
    func syncModulesToiCloud() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self, let iCloudURL = self.ubiquityContainerURL else { return }
            
            let localModulesURL = self.getLocalModulesFileURL()
            let iCloudModulesURL = iCloudURL.appendingPathComponent("modules.json")
            
            do {
                guard FileManager.default.fileExists(atPath: localModulesURL.path) else { return }
                
                let localData = try Data(contentsOf: localModulesURL)
                let _ = try JSONSerialization.jsonObject(with: localData, options: [])
                
                if FileManager.default.fileExists(atPath: iCloudModulesURL.path) {
                    try FileManager.default.removeItem(at: iCloudModulesURL)
                }
                try FileManager.default.copyItem(at: localModulesURL, to: iCloudModulesURL)
                
            } catch {
                Logger.shared.log("iCloud modules sync error: \(error)", type: "Error")
            }
        }
    }
    
    func syncModulesFromiCloud() {
        guard let iCloudURL = self.ubiquityContainerURL else {
            Logger.shared.log("iCloud container not available", type: "Error")
            return
        }
        
        let localModulesURL = self.getLocalModulesFileURL()
        let iCloudModulesURL = iCloudURL.appendingPathComponent("modules.json")
        
        do {
            if !FileManager.default.fileExists(atPath: iCloudModulesURL.path) {
                Logger.shared.log("No modules file found in iCloud", type: "Info")
                
                if FileManager.default.fileExists(atPath: localModulesURL.path) {
                    Logger.shared.log("Copying local modules file to iCloud", type: "Info")
                    try FileManager.default.copyItem(at: localModulesURL, to: iCloudModulesURL)
                } else {
                    Logger.shared.log("Creating new empty modules file in iCloud", type: "Info")
                    let emptyModules: [ScrapingModule] = []
                    let emptyData = try JSONEncoder().encode(emptyModules)
                    try emptyData.write(to: iCloudModulesURL)
                    
                    try emptyData.write(to: localModulesURL)
                    
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .modulesSyncDidComplete, object: nil)
                    }
                }
                return
            }
            
            let shouldCopy: Bool
            if FileManager.default.fileExists(atPath: localModulesURL.path) {
                let localData = try Data(contentsOf: localModulesURL)
                let iCloudData = try Data(contentsOf: iCloudModulesURL)
                shouldCopy = localData != iCloudData
            } else {
                shouldCopy = true
            }
            
            if shouldCopy {
                Logger.shared.log("Syncing modules from iCloud", type: "Info")
                if FileManager.default.fileExists(atPath: localModulesURL.path) {
                    try FileManager.default.removeItem(at: localModulesURL)
                }
                try FileManager.default.copyItem(at: iCloudModulesURL, to: localModulesURL)
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .modulesSyncDidComplete, object: nil)
                }
            }
        } catch {
            Logger.shared.log("iCloud modules sync error: \(error)", type: "Error")
        }
    }
    
    private func getLocalModulesFileURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("modules.json")
    }
    
    private func isValidPropertyListArray(_ array: [Any]) -> Bool {
        for item in array {
            if !isValidPropertyListType(item) {
                return false
            }
        }
        return true
    }
    
    private func isValidPropertyListDictionary(_ dict: [String: Any]) -> Bool {
        for (_, value) in dict {
            if !isValidPropertyListType(value) {
                return false
            }
        }
        return true
    }
    
    private func isValidPropertyListType(_ value: Any) -> Bool {
        if value is String || value is Bool || value is Int || value is Float || value is Double || value is Data || value is Date {
            return true
        } else if let array = value as? [Any] {
            return isValidPropertyListArray(array)
        } else if let dict = value as? [String: Any] {
            return isValidPropertyListDictionary(dict)
        }
        return false
    }
}
