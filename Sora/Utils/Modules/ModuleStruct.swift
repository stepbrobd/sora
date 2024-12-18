//
//  ModuleStruct.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import Foundation

struct ModuleStruct: Codable {
    let name: String
    let version: String
    let author: Author
    let iconURL: String
    let stream: String
    let language: String
    let extractor: String
    let module: [Module]
    
    struct Author: Codable {
        let name: String
        let website: String
    }
    
    struct Module: Codable, Hashable {
        let search: Search
        let featured: Featured
        let details: Details
        let episodes: Episodes
        
        struct Search: Codable, Hashable {
            let url: String
            let parameter: String
            let documentSelector: String
            let title: String
            let image: Image
            let href: String
            
            struct Image: Codable, Hashable {
                let url: String
                let attribute: String
            }
        }
        
        struct Featured: Codable, Hashable {
            let url: String
            let documentSelector: String
            let title: String
            let image: Image
            let href: String
            
            struct Image: Codable, Hashable {
                let url: String
                let attribute: String
            }
        }
        
        struct Details: Codable, Hashable {
            let baseURL: String
            let aliases: Aliases
            let synopsis: String
            let airdate: String
            let stars: String
            
            struct Aliases: Codable, Hashable {
                let selector: String
                let attribute: String
            }
        }
        
        struct Episodes: Codable, Hashable {
            let selector: String
            let order: String
        }
    }
}
