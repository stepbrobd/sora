//
//  ContinueWatchingManager.swift
//  Sora
//
//  Created by Francesco on 14/02/25.
//

import Foundation

class ContinueWatchingManager {
    static let shared = ContinueWatchingManager()
    private let storageKey = "continueWatchingItems"
    
    private init() {}
    
    func save(item: ContinueWatchingItem) {
        var items = fetchItems()
        if let index = items.firstIndex(where: { $0.streamUrl == item.streamUrl && $0.episodeNumber == item.episodeNumber }) {
            items[index] = item
        } else {
            items.append(item)
        }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    func fetchItems() -> [ContinueWatchingItem] {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let items = try? JSONDecoder().decode([ContinueWatchingItem].self, from: data) {
            return items
        }
        return []
    }
}
