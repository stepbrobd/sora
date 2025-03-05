//
//  TMDBItem.swift
//  Sulfur
//
//  Created by Francesco on 05/03/25.
//

import Foundation

struct TMDBItem: Codable {
    let id: Int
    let mediaType: String?
    
    let title: String?
    let originalTitle: String?
    let releaseDate: String?
    
    let name: String?
    let originalName: String?
    let firstAirDate: String?
    
    let posterPath: String?
    let backdropPath: String?
    let overview: String
    let voteAverage: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, overview
        case mediaType = "media_type"
        case title, name
        case originalTitle = "original_title"
        case originalName = "original_name"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
    }
    
    var displayTitle: String {
        return title ?? name ?? "Unknown Title"
    }
    
    var posterURL: String {
        if let path = posterPath {
            return "https://image.tmdb.org/t/p/w500\(path)"
        }
        return ""
    }
    
    var backdropURL: String {
        if let path = backdropPath {
            return "https://image.tmdb.org/t/p/original\(path)"
        }
        return ""
    }
    
    var displayDate: String {
        return releaseDate ?? firstAirDate ?? ""
    }
}
