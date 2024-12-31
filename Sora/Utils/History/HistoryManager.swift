//
//  HistoryManager.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import Foundation
import Combine

class HistoryManager: ObservableObject {
    @Published var searchHistory: [String] = UserDefaults.standard.stringArray(forKey: "SearchHistory") ?? []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.searchHistory = UserDefaults.standard.stringArray(forKey: "SearchHistory") ?? []
                }
            }
            .store(in: &cancellables)
    }
    
    func addSearchHistory(_ item: String) {
        if !searchHistory.contains(item) {
            searchHistory.insert(item, at: 0)
            UserDefaults.standard.set(searchHistory, forKey: "SearchHistory")
        }
    }
    
    func deleteHistoryItem(at offsets: IndexSet) {
        searchHistory.remove(atOffsets: offsets)
        UserDefaults.standard.set(searchHistory, forKey: "SearchHistory")
    }
}
