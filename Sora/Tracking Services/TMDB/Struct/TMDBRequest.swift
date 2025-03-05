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
    private static let Token = "ZXlKaGJHY2lPaUpJVXpJMU5pSjkuZXlKaGRXUWlPaUkzTXpoaU5HVmtaREJoTVRVMlkyTXhNalprWXpSaE5HSTRZV1ZoTkdGallTSXNJbTVpWmlJNk1UYzBNVEUzTXpjd01pNDNPRGN3TURBeUxDSnpkV0lpT2lJMk4yTTRNek5qTm1RM05ERTVZMlJtWkRnMlpUSmtaR1lpTENKelkyOXdaWE1pT2xzaVlYQnBYM0psWVdRaVhTd2lkbVZ5YzJsdmJpSTZNWDAuR2ZlN0YtOENXSlhnT052MzRtZzNqSFhmTDZCeGJqLWhBWWY5ZllpOUNrRQ=="
    
    static func getToken() -> String {
        guard let tokenData = Data(base64Encoded: Token),
              let token = String(data: tokenData, encoding: .utf8) else {
            fatalError("Failed to decode token.")
        }
        return token
    }
}
