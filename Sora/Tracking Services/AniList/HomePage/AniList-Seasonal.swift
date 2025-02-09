//
//  AniList-Seasonal.swift
//  Sora
//
//  Created by Francesco on 09/02/25.
//

import Foundation

class AnilistServiceSeasonalAnime {
    func fetchSeasonalAnime(completion: @escaping ([AniListItem]?) -> Void) {
        let currentDate = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: currentDate)
        let month = calendar.component(.month, from: currentDate)
        
        let season: String
        switch month {
        case 1...3:
            season = "WINTER"
        case 4...6:
            season = "SPRING"
        case 7...9:
            season = "SUMMER"
        default:
            season = "FALL"
        }
        
        let query = """
        query {
          Page(page: 1, perPage: 100) {
            media(season: \(season), seasonYear: \(year), type: ANIME, isAdult: false) {
              id
              title {
                romaji
                english
                native
              }
              coverImage {
                large
              }
            }
          }
        }
        """
        
        guard let url = URL(string: "https://graphql.anilist.co") else {
            print("Invalid URL")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = ["query": query]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        } catch {
            print("Error encoding JSON: \(error.localizedDescription)")
            completion(nil)
            return
        }
        
        let task = URLSession.custom.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching seasonal anime: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let data = data else {
                    print("No data returned")
                    completion(nil)
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let dataObject = json["data"] as? [String: Any],
                       let page = dataObject["Page"] as? [String: Any],
                       let media = page["media"] as? [[String: Any]] {
                        
                        let seasonalAnime: [AniListItem] = media.compactMap { item -> AniListItem? in
                            guard let id = item["id"] as? Int,
                                  let titleData = item["title"] as? [String: Any],
                                  let romaji = titleData["romaji"] as? String,
                                  let english = titleData["english"] as? String?,
                                  let native = titleData["native"] as? String?,
                                  let coverImageData = item["coverImage"] as? [String: Any],
                                  let largeImageUrl = coverImageData["large"] as? String,
                                  URL(string: largeImageUrl) != nil else {
                                return nil
                            }
                            
                            return AniListItem(
                                id: id,
                                title: AniListTitle(romaji: romaji, english: english, native: native),
                                coverImage: AniListCoverImage(large: largeImageUrl)
                            )
                        }
                        completion(seasonalAnime)
                    } else {
                        print("Error parsing JSON or missing expected fields")
                        completion(nil)
                    }
                } catch {
                    print("Error decoding JSON: \(error.localizedDescription)")
                    completion(nil)
                }
            }
        }
        task.resume()
    }
}
