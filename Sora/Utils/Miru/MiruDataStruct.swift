//
//  MiruDataStruct.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import Foundation

struct MiruDataStruct: Codable {
    var likes: [Like]
    
    struct Like: Codable {
        let anilistID: Int
        var gogoSlug: String
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
