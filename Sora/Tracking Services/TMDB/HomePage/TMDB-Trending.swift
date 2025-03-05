//
//  TMDB-Trending.swift
//  Sulfur
//
//  Created by Francesco on 05/03/25.
//

import Foundation

class TMBDTrending {    
    static func fetchTMDBTrending(completion: @escaping ([AniListItem]?) -> Void) {
        Task {
            do {
                let items = try await fetchTrendingItems()
                
                let anilistItems = items.map { item in
                    AniListItem(
                        id: item.id,
                        title: AniListTitle(
                            romaji: item.displayTitle,
                            english: item.originalTitle ?? item.originalName ?? item.displayTitle,
                            native: ""
                        ),
                        coverImage: AniListCoverImage(
                            large: item.posterURL
                        )
                    )
                }
                
                DispatchQueue.main.async {
                    completion(anilistItems)
                }
            } catch {
                DispatchQueue.main.async {
                    Logger.shared.log("Error fetching TMDB trending: \(error.localizedDescription)")
                    completion(nil)
                }
            }
        }
    }
    
    private static func fetchTrendingItems() async throws -> [TMDBItem] {
        let url = URL(string: "https://api.themoviedb.org/3/trending/all/day")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "language", value: "en-US")
        ]
        components.queryItems = queryItems
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.allHTTPHeaderFields = [
            "accept": "application/json",
            "Authorization": "Bearer \(TMBDRequest.decryptToken())"
        ]
        
        let (data, _) = try await URLSession.custom.data(for: request)
        let response = try JSONDecoder().decode(TMDBResponse.self, from: data)
        return response.results
    }
}
