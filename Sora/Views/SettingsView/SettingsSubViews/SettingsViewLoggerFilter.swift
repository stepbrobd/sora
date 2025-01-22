//
//  SettingsViewLoggerFilter.swift
//  Sora
//
//  Created by seiike on 21/01/2025.
//

import SwiftUI

struct LogFilter: Identifiable, Hashable {
    let id = UUID()
    let type: String
    var isEnabled: Bool
    let description: String
}


class LogFilterViewModel: ObservableObject {
    static let shared = LogFilterViewModel() // Singleton instance

    @Published var filters: [LogFilter] = [] {
        didSet {
            saveFiltersToUserDefaults()
        }
    }
    
    private let userDefaultsKey = "LogFilterStates"
    private let hardcodedFilters: [(type: String, description: String, defaultState: Bool)] = [
        ("Global", "Logs for general events and activities.", true), // Turned on by default
        ("Stream", "Logs for streaming and video playback.", true), // Turned on by default
        ("Error", "Logs for errors and critical issues.", true), // Turned on by default
        ("Debug", "Logs for debugging and troubleshooting.", false) // Turned off by default
    ]
    
    private init() {
        loadFilters()
    }
    
    func loadFilters() {
        if let savedStates = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: Bool] {
            filters = hardcodedFilters.map {
                LogFilter(
                    type: $0.type,
                    isEnabled: savedStates[$0.type] ?? $0.defaultState, // Use saved state if available, otherwise default
                    description: $0.description
                )
            }
        } else {
            filters = hardcodedFilters.map {
                LogFilter(type: $0.type, isEnabled: $0.defaultState, description: $0.description)
            }
        }
    }
    
    func toggleFilter(for type: String) {
        if let index = filters.firstIndex(where: { $0.type == type }) {
            filters[index].isEnabled.toggle()
        }
    }
    
    func isFilterEnabled(for type: String) -> Bool {
        return filters.first(where: { $0.type == type })?.isEnabled ?? true
    }
    
    private func saveFiltersToUserDefaults() {
        let states = filters.reduce(into: [String: Bool]()) { result, filter in
            result[filter.type] = filter.isEnabled
        }
        UserDefaults.standard.set(states, forKey: userDefaultsKey)
    }
}


struct SettingsViewLoggerFilter: View {
    @ObservedObject var viewModel = LogFilterViewModel.shared

    var body: some View {
        List {
            ForEach($viewModel.filters) { $filter in
                VStack(alignment: .leading, spacing: 5) {
                    Toggle(filter.type, isOn: $filter.isEnabled)
                        .font(.headline)
                    
                    Text(filter.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 5) // Indent description slightly
                }
                .padding(.vertical, 5)
            }
        }
        .navigationTitle("Log Filters")
    }
}
