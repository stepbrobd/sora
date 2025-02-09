//
//  AniListItem.swift
//  Sora
//
//  Created by Francesco on 09/02/25.
//

import Foundation

struct AniListItem: Codable {
    let id: Int
    let title: AniListTitle
    let coverImage: AniListCoverImage
}

struct AniListTitle: Codable {
    let romaji: String
    let english: String?
    let native: String?
}

struct AniListCoverImage: Codable {
    let large: String
}
