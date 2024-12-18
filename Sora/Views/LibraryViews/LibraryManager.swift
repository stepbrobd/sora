//
//  LibraryManager.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import Foundation

class LibraryManager: ObservableObject {
    static let shared = LibraryManager()
    
    @Published var libraryItems: [LibraryItem] = []
    private let userDefaults = UserDefaults.standard
    private let libraryKey = "LibraryItems"
    
    private init() {
        loadLibrary()
    }
    
    func loadLibrary() {
        if let data = userDefaults.data(forKey: libraryKey),
           let decoded = try? JSONDecoder().decode([LibraryItem].self, from: data) {
            libraryItems = decoded
        }
    }
    
    func saveLibrary() {
        if let encoded = try? JSONEncoder().encode(libraryItems) {
            userDefaults.set(encoded, forKey: libraryKey)
        }
    }
    
    func addToLibrary(_ item: LibraryItem) {
        if !libraryItems.contains(where: { $0.anilistID == item.anilistID }) {
            libraryItems.append(item)
            saveLibrary()
            Logger.shared.log("Added to library: \(item.title)")
        }
    }
    
    func removeFromLibrary(_ item: LibraryItem) {
        libraryItems.removeAll(where: { $0.id == item.id })
        saveLibrary()
        Logger.shared.log("Removed from library: \(item.title)")
    }
    
    func importFromMiruData(_ miruData: MiruDataStruct) {
        var newLibraryItems: [LibraryItem] = []
        
        for like in miruData.likes {
            let libraryItem = LibraryItem(
                anilistID: like.anilistID,
                title: like.title,
                image: like.cover,
                url: like.gogoSlug,
                dateAdded: Date()
            )
            newLibraryItems.append(libraryItem)
            Logger.shared.log("Importing item: \(libraryItem.title)")
        }
        
        DispatchQueue.main.async {
            self.libraryItems = newLibraryItems
            self.saveLibrary()
            Logger.shared.log("Completed importing \(newLibraryItems.count) items")
        }
    }
}
