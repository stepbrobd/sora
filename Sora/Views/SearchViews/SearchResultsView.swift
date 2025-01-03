//
//  SearchResultsView.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI
import SwiftSoup
import Kingfisher

struct SearchResultsView: View {
    let module: ModuleStruct?
    let searchText: String
    @State private var searchResults: [ItemResult] = []
    @State private var isLoading: Bool = true
    @State private var filter: FilterType = .all
    @AppStorage("listSearch") private var isListSearchEnabled: Bool = false
    
    enum FilterType: String, CaseIterable {
        case all = "All"
        case dub = "Dub"
        case sub = "Sub"
        case ova = "OVA"
        case ona = "ONA"
        case movie = "Movie"
    }
    
    var body: some View {
        if isListSearchEnabled {
            oldUI
        } else {
            modernUI
        }
    }
    
    var modernUI: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .padding()
            } else if searchResults.isEmpty {
                Text("No results found")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                        ForEach(filteredResults) { result in
                            NavigationLink(destination: MediaView(module: module!, item: result)) {
                                VStack {
                                    KFImage(URL(string: result.imageUrl))
                                        .resizable()
                                        .aspectRatio(2/3, contentMode: .fill)
                                        .cornerRadius(10)
                                        .frame(width: 150, height: 225)
                                    
                                    Text(result.name)
                                        .font(.subheadline)
                                        .foregroundColor(Color.primary)
                                        .padding([.leading, .bottom], 8)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .navigationTitle("Results")
                .toolbar {
                    filterMenu
                }
            }
        }
        .onAppear {
            performSearch()
        }
    }
    
    var oldUI: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .padding()
            } else if searchResults.isEmpty {
                Text("No results found")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(filteredResults) { result in
                        NavigationLink(destination: MediaView(module: module!, item: result)) {
                            HStack {
                                KFImage(URL(string: result.imageUrl))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 150)
                                    .clipped()
                                
                                VStack(alignment: .leading) {
                                    Text(result.name)
                                        .font(.system(size: 16))
                                        .padding(.leading, 10)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
                .navigationTitle("Results")
                .toolbar {
                    filterMenu
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            performSearch()
        }
    }
    
    var filterMenu: some View {
        Menu {
            ForEach([FilterType.all], id: \.self) { filter in
                Button(action: {
                    self.filter = filter
                    performSearch()
                }) {
                    Label(filter.rawValue, systemImage: self.filter == filter ? "checkmark" : "")
                }
            }
            Menu("Audio") {
                ForEach([FilterType.dub, FilterType.sub], id: \.self) { filter in
                    Button(action: {
                        self.filter = filter
                        performSearch()
                    }) {
                        Label(filter.rawValue, systemImage: self.filter == filter ? "checkmark" : "")
                    }
                }
            }
            Menu("Format") {
                ForEach([FilterType.ova, FilterType.ona, FilterType.movie], id: \.self) { filter in
                    Button(action: {
                        self.filter = filter
                        performSearch()
                    }) {
                        Label(filter.rawValue, systemImage: self.filter == filter ? "checkmark" : "")
                    }
                }
            }
        } label: {
            Label("Filter", systemImage: filter == .all ? "line.horizontal.3.decrease.circle" : "line.horizontal.3.decrease.circle.fill")
        }
    }
    
    var filteredResults: [ItemResult] {
        switch filter {
        case .all:
            return searchResults
        case .dub:
            return searchResults.filter { $0.name.contains("Dub") || $0.name.contains("ITA") }
        case .sub:
            return searchResults.filter { !$0.name.contains("Dub") && !$0.name.contains("ITA") }
        case .ova, .ona:
            return searchResults.filter { $0.name.contains(filter.rawValue) }
        case .movie:
            return searchResults.filter { $0.name.contains("Movie") || $0.name.contains("Film") }
        }
    }
    
    func performSearch() {
        guard let module = module, !searchText.isEmpty else { return }
        
        let encodedSearchText = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchText
        let parameter = module.module[0].search.parameter
        let urlString: String
        
        if parameter == "blank" {
            urlString = "\(module.module[0].search.url)\(encodedSearchText)"
        } else {
            urlString = "\(module.module[0].search.url)?\(parameter)=\(encodedSearchText)"
        }
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.custom.dataTask(with: url) { data, _, error in
            defer { isLoading = false }
            guard let data = data, error == nil else { return }
            
            do {
                let html = String(data: data, encoding: .utf8) ?? ""
                let document = try SwiftSoup.parse(html)
                let elements = try document.select(module.module[0].search.documentSelector)
                
                var results: [ItemResult] = []
                for element in elements {
                    let title = try element.select(module.module[0].search.title).text()
                    let href = try element.select(module.module[0].search.href).attr("href")
                    var imageURL = try element.select(module.module[0].search.image.url).attr(module.module[0].search.image.attribute)
                    
                    if imageURL.contains(",") {
                        imageURL = imageURL.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.first ?? imageURL
                    }
                    
                    if !imageURL.starts(with: "http") {
                        imageURL = "\(module.module[0].details.baseURL.hasSuffix("/") ? module.module[0].details.baseURL : "\(module.module[0].details.baseURL)/")\(imageURL.hasPrefix("/") ? String(imageURL.dropFirst()) : imageURL)"
                    }
                    
                    imageURL = imageURL.replacingOccurrences(of: " ", with: "%20")
                    
                    // If imageURL is not available or is the same as the baseURL, use a default image
                    if imageURL.isEmpty || imageURL == module.module[0].details.baseURL + "/" {
                        imageURL = "https://s4.anilist.co/file/anilistcdn/character/large/default.jpg"
                    }
                    
                    let result = ItemResult(name: title, imageUrl: imageURL, href: href)
                    results.append(result)
                }
                
                // Filter out non-searchable modules
                if module.module[0].search.searchable == false {
                    results = results.filter { $0.name.lowercased().contains(searchText.lowercased()) }
                }
                
                DispatchQueue.main.async {
                    self.searchResults = results
                }
            } catch {
                print("Error parsing HTML: \(error)")
                Logger.shared.log("Error parsing HTML: \(error)")
            }
        }.resume()
    }
}
