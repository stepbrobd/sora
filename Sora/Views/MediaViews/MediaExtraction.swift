//
//  MediaExtraction.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI
import SwiftSoup

extension MediaView {
    func fetchItemDetails() {
        guard let url = URL(string: item.href.hasPrefix("https") ? item.href : "\(module.module[0].details.baseURL.hasSuffix("/") ? module.module[0].details.baseURL : "\(module.module[0].details.baseURL)/")\(item.href.hasPrefix("/") ? String(item.href.dropFirst()) : item.href)") else { return }
        
        URLSession.custom.dataTask(with: url) { data, response, error in
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
    
    func fetchEpisodeStream(urlString: String) {
        guard let url = URL(string: urlString.hasPrefix("https") ? urlString : "\(module.module[0].details.baseURL)\(urlString)") else { return }
        
        Logger.shared.log("Pressed episode button")
        URLSession.custom.dataTask(with: url) { data, response, error in
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
                        self.presentStreamSelection(subURLs: subURLs, dubURLs: dubURLs, fullURL: urlString)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.playStream(urlString: streamURLs.first, fullURL: urlString)
                    }
                }
            } else if module.extractor == "pattern-mp4" || module.extractor == "pattern-HLS" {
                Logger.shared.log("extracting for pattern-mp4/hls")
                let patternURL = extractPatternURL(from: html)
                guard let patternURL = patternURL else { return }
                
                URLSession.custom.dataTask(with: patternURL) { data, response, error in
                    guard let data = data, error == nil else { return }
                    
                    let patternHTML = String(data: data, encoding: .utf8) ?? ""
                    let mp4URLs = extractStreamURLs(from: patternHTML, streamType: streamType).map { $0.replacingOccurrences(of: "amp;", with: "") }
                    
                    DispatchQueue.main.async {
                        self.playStream(urlString: mp4URLs.first, fullURL: urlString)
                    }
                }.resume()
            } else if module.extractor == "pattern" {
                Logger.shared.log("extracting for pattern")
                let patternURL = extractPatternURL(from: html)
                
                DispatchQueue.main.async {
                    self.playStream(urlString: patternURL?.absoluteString, fullURL: urlString)
                }
            } else {
                DispatchQueue.main.async {
                    self.playStream(urlString: streamURLs.first, fullURL: urlString)
                }
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
    
    func extractPatternURL(from html: String) -> URL? {
        var pattern = module.module[0].episodes.pattern
        
        if module.extractor == "pattern" {
            if let data = Data(base64Encoded: pattern), let decodedPattern = String(data: data, encoding: .utf8) {
                pattern = decodedPattern
            } else {
                print("Failed to decode base64 pattern")
                Logger.shared.log("Failed to decode base64 pattern")
                return nil
            }
        }
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            
            if let match = regex.firstMatch(in: html, options: [], range: range),
               let matchRange = Range(match.range, in: html) {
                var urlString = String(html[matchRange])
                urlString = urlString.replacingOccurrences(of: "amp;", with: "")
                urlString = urlString.replacingOccurrences(of: "\"", with: "")
                
                if let httpsRange = urlString.range(of: "https") {
                    urlString = String(urlString[httpsRange.lowerBound...])
                }
                
                return URL(string: urlString)
            }
        } catch {
            print("Invalid regex: \(error)")
            Logger.shared.log("Invalid regex: \(error)")
        }
        return nil
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
    
    func presentStreamSelection(subURLs: [String], dubURLs: [String], fullURL: String) {
        let uniqueSubURLs = Array(Set(subURLs))
        let uniqueDubURLs = Array(Set(dubURLs))
        
        let alert = UIAlertController(title: "Select Stream", message: "Choose the audio type", preferredStyle: .actionSheet)
        
        if !uniqueDubURLs.isEmpty {
            for dubURL in uniqueDubURLs {
                alert.addAction(UIAlertAction(title: "DUB", style: .default) { _ in
                    self.playStream(urlString: dubURL, fullURL: fullURL)
                })
            }
        }
        
        if !uniqueSubURLs.isEmpty {
            for subURL in uniqueSubURLs {
                alert.addAction(UIAlertAction(title: "SUB", style: .default) { _ in
                    self.playStream(urlString: subURL, fullURL: fullURL)
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
