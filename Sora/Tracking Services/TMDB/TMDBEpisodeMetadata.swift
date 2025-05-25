//
//  TMDBEpisodeMetadata.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import Foundation

struct TMDBEpisodeMetadata: Codable {
    let title: String
    let imageUrl: String
    let tmdbId: Int
    let seasonNumber: Int
    let episodeNumber: Int
    let cacheDate: Date
    
    var cacheKey: String {
        return "tmdb_\(tmdbId)_s\(seasonNumber)_e\(episodeNumber)"
    }
    
    init(title: String, imageUrl: String, tmdbId: Int, seasonNumber: Int, episodeNumber: Int) {
        self.title = title
        self.imageUrl = imageUrl
        self.tmdbId = tmdbId
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.cacheDate = Date()
    }
    
    func toData() -> Data? {
        return try? JSONEncoder().encode(self)
    }
    
    static func fromData(_ data: Data) -> TMDBEpisodeMetadata? {
        return try? JSONDecoder().decode(TMDBEpisodeMetadata.self, from: data)
    }
}
