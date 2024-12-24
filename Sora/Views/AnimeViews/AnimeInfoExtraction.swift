//
//  AnimeInfoExtraction.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI
import SwiftSoup

extension AnimeInfoView {
    func fetchAnimeDetails() {
        guard let url = URL(string: anime.href.hasPrefix("https") ? anime.href : "\(module.module[0].details.baseURL)\(anime.href)") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            defer { isLoading = false }
            guard let data = data, error == nil else { return }
            
            do {
                let html = String(data: data, encoding: .utf8) ?? ""
                let document = try SwiftSoup.parse(html)
                
                let details = module.module[0].details
                let episodes = module.module[0].episodes
                
                let aliases = (try? document.select(details.aliases.selector).attr(details.aliases.attribute)) ?? ""
                let synopsis = (try? document.select(details.synopsis).text()) ?? ""
                let airdate = (try? document.select(details.airdate).text()) ?? ""
                let stars = (try? document.select(details.stars).text()) ?? ""
                
                let episodeElements = try document.select(episodes.selector)
                var episodeList = (try? episodeElements.map { try $0.attr("href") }) ?? []
                
                if module.module[0].episodes.order == "reversed" {
                    episodeList.reverse()
                }
                
                DispatchQueue.main.async {
                    self.aliases = aliases
                    self.synopsis = synopsis
                    self.airdate = airdate
                    self.stars = stars
                    self.episodes = episodeList
                }
            } catch {
                print("Error parsing HTML: \(error)")
                Logger.shared.log("Error parsing HTML: \(error)")
            }
        }.resume()
    }
    
    func extractStreamURLs(from html: String, streamType: String) -> [String] {
        let pattern: String
        switch streamType {
        case "HLS":
            pattern = #"https:\/\/[^"\s<>]+\.m3u8(?:\?[^\s"'<>]+)?"#
        case "MP4":
            pattern = #"https:\/\/(?:(?!php).)+\.mp4(?:\?[^\s"'<>]+)?"#
        default:
            return []
        }
        
        do {
            Logger.shared.log(streamType)
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
            return matches.compactMap {
                Range($0.range, in: html).map { String(html[$0]) }
            }
        } catch {
            print("Invalid regex: \(error)")
            Logger.shared.log("Invalid regex: \(error)")
            return []
        }
    }
    
    func extractDubSubURLs(from htmlContent: String) -> [(type: String, url: String)] {
        let pattern = #""type":"(SUB|DUB)","url":"(.*?\.m3u8)""#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        let range = NSRange(htmlContent.startIndex..., in: htmlContent)
        let matches = regex.matches(in: htmlContent, range: range)
        
        return matches.compactMap { match in
            if match.numberOfRanges == 3,
               let typeRange = Range(match.range(at: 1), in: htmlContent),
               let urlRange = Range(match.range(at: 2), in: htmlContent) {
                let type = String(htmlContent[typeRange])
                let urlString = String(htmlContent[urlRange]).replacingOccurrences(of: "\\/", with: "/")
                Logger.shared.log(urlString)
                return (type, urlString)
            }
            return nil
        }
    }
    
    func fetchEpisodeStream(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        Logger.shared.log("Pressed episode button")
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            
            let html = String(data: data, encoding: .utf8) ?? ""
            let streamType = module.stream
            let streamURLs = extractStreamURLs(from: html, streamType: streamType)
            
            if module.extractor == "dub-sub" {
                Logger.shared.log("extracting for dub-sub")
                let dubSubURLs = extractDubSubURLs(from: html)
                let subURLs = dubSubURLs.filter { $0.type == "SUB" }.map { $0.url }
                let dubURLs = dubSubURLs.filter { $0.type == "DUB" }.map { $0.url }
                
                if !subURLs.isEmpty || !dubURLs.isEmpty {
                    DispatchQueue.main.async {
                        self.presentStreamSelection(subURLs: subURLs, dubURLs: dubURLs)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.playStream(urlString: streamURLs.first, fullURL: urlString)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    Logger.shared.log("stream URLs: \(streamURLs)")
                    self.playStream(urlString: streamURLs.first, fullURL: urlString)
                }
            }
        }.resume()
    }
    
    func presentStreamSelection(subURLs: [String], dubURLs: [String]) {
        let uniqueSubURLs = Array(Set(subURLs))
        let uniqueDubURLs = Array(Set(dubURLs))
        
        let alert = UIAlertController(title: "Select Stream", message: "Choose the audio type", preferredStyle: .actionSheet)
        
        if !uniqueDubURLs.isEmpty {
            for dubURL in uniqueDubURLs {
                alert.addAction(UIAlertAction(title: "DUB", style: .default) { _ in
                    self.playStream(urlString: dubURL, fullURL: dubURL)
                })
            }
        }
        
        if !uniqueSubURLs.isEmpty {
            for subURL in uniqueSubURLs {
                alert.addAction(UIAlertAction(title: "SUB", style: .default) { _ in
                    self.playStream(urlString: subURL, fullURL: subURL)
                })
            }
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                if let popoverController = alert.popoverPresentationController {
                    popoverController.sourceView = rootVC.view
                    popoverController.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                    popoverController.permittedArrowDirections = []
                }
                rootVC.present(alert, animated: true, completion: nil)
            }
        }
    }
}
