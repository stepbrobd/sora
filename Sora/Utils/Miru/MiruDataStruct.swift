//
//  MiruDataStruct.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import Foundation

struct MiruDataStruct: Codable {
    let likes: [Like]
    
    struct Like: Codable {
        let anilistID: Int
        let gogoSlug: String
        let title: String
        let cover: String
        
        enum CodingKeys: String, CodingKey {
            case anilistID = "anilist_id"
            case gogoSlug = "gogo_slug"
            case title
            case cover
        }
    }
}
