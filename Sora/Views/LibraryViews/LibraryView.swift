//
//  LibraryView.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI
import Kingfisher
import Foundation

struct LibraryItem: Identifiable, Codable {
    var id = UUID()
    let anilistID: Int
    let title: String
    let image: String
    let url: String
    let module: ModuleStruct
    var dateAdded: Date
}

struct LibraryView: View {
    @StateObject private var libraryManager = LibraryManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                if libraryManager.libraryItems.isEmpty {
                    emptyLibraryView
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                        ForEach(libraryManager.libraryItems.sorted(by: { $0.dateAdded > $1.dateAdded })) { item in
                            NavigationLink(destination: MediaView(module: item.module, item: ItemResult(name: item.title, imageUrl: item.image, href: item.url))) {
                                itemView(item)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Library")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    var emptyLibraryView: some View {
        VStack(spacing: 8) {
            Image(systemName: "books.vertical")
                .font(.system(size: 75))
                .foregroundColor(.secondary)
            Text("Your library is empty")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Start by adding items you find in the search results or by importing Miru bookmarks from settings!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 3)
    }
    
    func itemView(_ item: LibraryItem) -> some View {
        VStack {
            KFImage(URL(string: item.image))
                .resizable()
                .aspectRatio(2/3, contentMode: .fill)
                .cornerRadius(10)
                .frame(width: 150, height: 225)
            
            Text(item.title)
                .font(.subheadline)
                .foregroundColor(Color.primary)
                .padding([.leading, .bottom], 8)
                .lineLimit(1)
        }
        .contextMenu {
            Button(role: .destructive) {
                libraryManager.removeFromLibrary(item)
            } label: {
                Label("Remove from Library", systemImage: "trash")
            }
        }
    }
}