//
//  TMDBRequest.swift
//  Sulfur
//
//  Created by Francesco on 05/03/25.
//

import Foundation

struct TMDBResponse: Codable {
    let results: [TMDBItem]
    let page: Int
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case results, page
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

class TMBDRequest {
    static let encodedTokenParts = [
        "XZXlKaGJHY2lPaUpJVXpJMU5pSjk=",
        "XZXlKaGRXUWlPaUkzTXpoaU5HVmtaREJoTVRVMlkyTXhNalprWXpSaE5HSTRZV1ZoTkdGallTSXNJbTVpWmlJNk1UYzBNVEUzTXpjd01pNDNPRGN3TURJc0luTjFZaUk2SWpZM1l6Z3pNMk0yWkRjME1UbGpaR1prT0RabE1tUmtaaUlzSW5OamIzQmxjeUk2V3lKaGNHbGZjbVZoWkNKZExDSjJaWEp6YVc5dUlqb3hmUT09",
        "XR2ZlN0YtOENXSlhnT052MzRtZzNqSFhmTDZCeGJqLWhBWWY5ZllpOUNrRQ=="
    ]
    
    static func decryptToken() -> String {
        let decodedParts = encodedTokenParts.map { part -> String in
            let cleanPart = String(part.dropFirst(1))
            guard let data = Data(base64Encoded: cleanPart) else {
                return ""
            }
            return String(data: data, encoding: .utf8) ?? ""
        }
        
        return decodedParts.joined()
    }
}
