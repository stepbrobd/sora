//
//  KingfisherManager.swift
//  Sora
//
//  Created by doomsboygaming on 5/22/25
//


import SwiftUI
import Foundation
import Kingfisher

class KingfisherCacheManager {
    private let jpegCompressionQuality: CGFloat = 0.7
    
    static let shared = KingfisherCacheManager()
    private let maxDiskCacheSize: UInt = 16 * 1024 * 1024
    private let maxCacheAgeInDays: TimeInterval = 7
    
    private let imageCachingEnabledKey = "imageCachingEnabled"
    
    var isCachingEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: imageCachingEnabledKey) == nil ?
            true : UserDefaults.standard.bool(forKey: imageCachingEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: imageCachingEnabledKey)
            configureKingfisher()
        }
    }
    
    private init() {
        configureKingfisher()
#if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(clearMemoryCacheOnWarning), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
#endif
    }
    
    @objc private func clearMemoryCacheOnWarning() {
        KingfisherManager.shared.cache.clearMemoryCache()
        KingfisherManager.shared.cache.clearDiskCache {
            Logger.shared.log("Cleared memory and disk cache due to memory warning", type: "Debug")
        }
    }
    
    func configureKingfisher() {
        let cache = ImageCache.default
        
        cache.diskStorage.config.sizeLimit = isCachingEnabled ? maxDiskCacheSize : 0
        cache.diskStorage.config.expiration = isCachingEnabled ?
            .days(Int(maxCacheAgeInDays)) : .seconds(1)
        
        cache.memoryStorage.config.totalCostLimit = isCachingEnabled ?
        4 * 1024 * 1024 : 0
        
        cache.memoryStorage.config.cleanInterval = 60
        
        KingfisherManager.shared.downloader.downloadTimeout = 15.0
        
        let processor = JPEGCompressionProcessor(compressionQuality: jpegCompressionQuality)
        KingfisherManager.shared.defaultOptions = [.processor(processor)]

        Logger.shared.log("Configured Kingfisher cache. Enabled: \(isCachingEnabled) | JPEG Compression: \(jpegCompressionQuality)", type: "Debug")
    }
    
    func clearCache(completion: (() -> Void)? = nil) {
        KingfisherManager.shared.cache.clearMemoryCache()
        KingfisherManager.shared.cache.clearDiskCache {
            Logger.shared.log("Cleared Kingfisher image cache", type: "General")
            completion?()
        }
    }
    
    func calculateCacheSize(completion: @escaping (UInt) -> Void) {
        KingfisherManager.shared.cache.calculateDiskStorageSize { result in
            switch result {
            case .success(let size):
                completion(size)
            case .failure(let error):
                Logger.shared.log("Failed to calculate image cache size: \(error)", type: "Error")
                completion(0)
            }
        }
    }
    
    static func formatCacheSize(_ sizeInBytes: UInt) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(sizeInBytes))
    }
}
