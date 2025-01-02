//
//  SearchView.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI

struct ItemResult: Identifiable {
    let id = UUID()
    let name: String
    let imageUrl: String
    let href: String
}

struct SearchView: View {
    @State private var searchText: String = ""
    @State private var searchResults: [ItemResult] = []
    @State private var navigateToResults: Bool = false
    @State private var selectedModule: ModuleStruct?
    @State private var showAlert = false
    @StateObject private var modulesManager = ModulesManager()
    @ObservedObject private var searchHistoryManager = HistoryManager()
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Menu {
                        ForEach(modulesManager.modules, id: \.name) { module in
                            Button(action: {
                                selectedModule = module
                            }) {
                                Text(module.name)
                            }
                        }
                    } label: {
                        Label(selectedModule?.name ?? "Select Module", systemImage: "chevron.down")
                    }
                    
                    Spacer()
                    
                    SearchBar(text: $searchText, onSearchButtonClicked: {
                        if let _ = selectedModule, !searchText.isEmpty {
                            searchHistoryManager.addSearchHistory(searchText)
                            navigateToResults = true
                        } else {
                            showAlert = true
                            Logger.shared.log("No Module is selected for the search")
                        }
                    })
                }
                .padding(.horizontal)
                
                List {
                    if !searchHistoryManager.searchHistory.isEmpty {
                        Section(header: Text("Search History")) {
                            ForEach(searchHistoryManager.searchHistory, id: \.self) { historyItem in
                                Button(action: {
                                    searchText = historyItem
                                    if let _ = selectedModule, !searchText.isEmpty {
                                        navigateToResults = true
                                    } else {
                                        showAlert = true
                                        Logger.shared.log("No Module is selected for the search")
                                    }
                                }) {
                                    Text(historyItem)
                                        .foregroundColor(.primary)
                                }
                            }
                            .onDelete(perform: searchHistoryManager.deleteHistoryItem)
                        }
                    }
                }
                .navigationTitle("Search")
                .onSubmit(of: .search) {
                    if let _ = selectedModule, !searchText.isEmpty {
                        navigateToResults = true
                    } else {
                        showAlert = true
                        Logger.shared.log("No Module is selected for the search")
                    }
                }
                
                NavigationLink(
                    destination: SearchResultsView(module: selectedModule, searchText: searchText),
                    isActive: $navigateToResults,
                    label: {
                        EmptyView()
                    }
                )
                    .hidden()
            }
            .onAppear {
                modulesManager.loadModules()
                NotificationCenter.default.addObserver(forName: .moduleAdded, object: nil, queue: .main) { _ in
                    modulesManager.loadModules()
                }
                NotificationCenter.default.addObserver(forName: .moduleRemoved, object: nil, queue: .main) { _ in
                    modulesManager.loadModules()
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("No module selected"),
                    message: Text("Please select a module before searching."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct SearchBar: View {
    @Binding var text: String
    var onSearchButtonClicked: () -> Void
    
    var body: some View {
        HStack {
            TextField("Search...", text: $text, onCommit: onSearchButtonClicked)
                .padding(7)
                .padding(.horizontal, 25)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                        
                        if !text.isEmpty {
                            Button(action: {
                                self.text = ""
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                )
                .padding(.horizontal, 10)
        }
    }
}
