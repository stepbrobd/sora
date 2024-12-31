//
//  GitHubAPI.swift
//  Sora
//
//  Created by Francesco on 31/12/24.
//

import Foundation

struct GitHubReleases: Codable {
    let tagName: String
    let body: String
    let htmlUrl: String
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case htmlUrl = "html_url"
    }
}

class GitHubAPI {
    static let shared = GitHubAPI()
    
    func fetchReleases(completion: @escaping ([GitHubReleases]?) -> Void) {
        let url = URL(string: "https://api.github.com/repos/cranci1/Sora/releases")!
        
        URLSession.custom.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            let releases = try? JSONDecoder().decode([GitHubReleases].self, from: data)
            completion(releases)
        }.resume()
    }
}
