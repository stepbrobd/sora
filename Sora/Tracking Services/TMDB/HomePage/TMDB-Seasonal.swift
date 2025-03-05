//
//  TMDB-Seasonal.swift
//  Sulfur
//
//  Created by Francesco on 05/03/25.
//

import Foundation

class TMDBSeasonal {
    static func fetchTMDBSeasonal(completion: @escaping ([AniListItem]?) -> Void) {
        Task {
            do {
                let url = URL(string: "https://api.themoviedb.org/3/movie/upcoming")!
                var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
                components.queryItems = [
                    URLQueryItem(name: "language", value: "en-US"),
                    URLQueryItem(name: "page", value: "1"),
                ]
                
                var request = URLRequest(url: components.url!)
                request.httpMethod = "GET"
                request.timeoutInterval = 10
                request.allHTTPHeaderFields = [
                    "accept": "application/json",
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
                    "Authorization": "Bearer \(TMBDRequest.decryptToken())"
                ]
                
                let (data, _) = try await URLSession.shared.data(for: request)
                let response = try JSONDecoder().decode(TMDBResponse.self, from: data)
                
                let anilistItems = response.results.map { item in
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
                    Logger.shared.log("Error fetching TMDB seasonal: \(error.localizedDescription)")
                    completion(nil)
                }
            }
        }
    }
}
