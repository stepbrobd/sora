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
        
        URLSession.custom.dataTask(with: url) { data, _, error in
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
        guard var url = URL(string: urlString.hasPrefix("https") ? urlString : "\(module.module[0].details.baseURL)\(urlString)") else { return }
        
        Logger.shared.log("Pressed episode button")
        
        let dispatchGroup = DispatchGroup()
        
        let pageRedirects = module.module[0].details.pageRedirects ?? false
        
        
        if pageRedirects {
            dispatchGroup.enter() // Start tracking the redirect task
            URLSession.custom.dataTask(with: url) { data, response, error in
                guard let data = data, error == nil else {
                    dispatchGroup.leave() // End tracking if there's an error
                    return
                }
                
                let html = String(data: data, encoding: .utf8) ?? ""
                let redirectedUrl = extractFromRedirectURL(from: html)
                if let redirect = redirectedUrl, let newURL = URL(string: redirect) {
                    url = newURL
                }
                dispatchGroup.leave() // End tracking after successful execution
            }.resume()
        }
        
        dispatchGroup.notify(queue: .main) { // This block executes after all tasks
            URLSession.custom.dataTask(with: url) { data, _, error in
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
                    
                    URLSession.custom.dataTask(with: patternURL) { data, _, error in
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
                } else if module.extractor == "voe" {
                    Logger.shared.log("extracting for voe")
                    
                    let voeUrl = extractVoeStream(from: html)
                    
                    DispatchQueue.main.async {
                        self.playStream(urlString: voeUrl?.absoluteString, fullURL: urlString)
                    }
                    
                } else {
                    DispatchQueue.main.async {
                        self.playStream(urlString: streamURLs.first, fullURL: urlString)
                    }
                }
            }.resume()
        }
    }
    
    func extractStreamURLs(from html: String, streamType: String) -> [String] {
        let pattern: String
        switch streamType {
        case "HLS":
            pattern = #"https:\/\/[^"\s<>]+\.m3u8(?:\?[^\s"'<>]+)?"#
        case "MP4":
            pattern = #"https:\/\/[^"\s<>]+\.mp4(?:\?[^\s"'<>]+)?"#
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
    
    /// Grabs hls stream from voe sites
    func extractVoeStream(from html: String) -> URL? {
        
        let hlsPattern = "'hls': '(.*?)'"
        guard let regex = try? NSRegularExpression(pattern: hlsPattern, options: []) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        if let match = regex.firstMatch(in: html, options: [], range: range),
           let matchRange = Range(match.range(at: 1), in: html) {
            let base64Hls = String(html[matchRange])
            guard let data = Data(base64Encoded: base64Hls),
                  let decodedURLString = String(data: data, encoding: .utf8)
            else { return nil }
            return URL(string: decodedURLString)
        }
        return nil
    }
    
    
    func presentStreamSelection(subURLs: [String], dubURLs: [String], fullURL: String) {
        let uniqueSubURLs = Array(Set(subURLs))
        let uniqueDubURLs = Array(Set(dubURLs))
        
        if uniqueSubURLs.count == 1 && uniqueDubURLs.isEmpty {
            self.playStream(urlString: uniqueSubURLs.first, fullURL: fullURL)
            return
        }
        
        if uniqueDubURLs.count == 1 && uniqueSubURLs.isEmpty {
            self.playStream(urlString: uniqueDubURLs.first, fullURL: fullURL)
            return
        }
        
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


    /// Extracts the URL from a redirect page
    /// Example: href="/redirect/1234567" -> https://baseUrl.com/redirect/1234567
    func extractFromRedirectURL(from html: String) -> String? {
        
        let pattern = #"href="\/redirect\/\d+""#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            
            if let match = regex.firstMatch(in: html, options: [], range: range),
               let matchRange = Range(match.range, in: html) {
                var urlString = String(html[matchRange])
                urlString = urlString.replacingOccurrences(of: "href=\"", with: "")
                urlString = urlString.replacingOccurrences(of: "\"", with: "")
                
                // Ensure the baseURL ends with "/" before appending the path
                let baseURL = module.module[0].details.baseURL
                
                let redirectUrl = baseURL + urlString
                
                let finalUrl = fetchRedirectedURLFromHeader(url: URL(string: redirectUrl)!)
                
                return finalUrl
            }
        } catch {
            print("Invalid regex: \(error)")
            Logger.shared.log("Invalid regex: \(error)")
        }
        return nil
    }
    
    /// Fetches the redirected URL from the header of a given URL
    /// Header Parameter: Location
    func fetchRedirectedURLFromHeader(url: URL) -> String? {
        let semaphore = DispatchSemaphore(value: 0) // To block the thread until the task completes
        var redirectedURLString: String?

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD" // Use HEAD to get only headers

        let delegate = RedirectHandler()
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)
        
        session.dataTask(with: request) { _, response, error in
            // Extract httpResponse as a standalone variable
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.shared.log("Invalid response for URL: \(url)")
                semaphore.signal()
                return
            }
            
            // Process the httpResponse for redirection logic
            if (httpResponse.statusCode == 301 || httpResponse.statusCode == 302),
               let location = httpResponse.value(forHTTPHeaderField: "Location"),
               let redirectedURL = URL(string: location) {
                redirectedURLString = redirectedURL.absoluteString
                Logger.shared.log("Redirected URL: \(redirectedURLString ?? "nil")")
            } else {
                if let error = error {
                    Logger.shared.log("Error fetching redirected URL: \(error.localizedDescription)")
                } else {
                    Logger.shared.log("No redirection for URL: \(url)")
                }
            }
            semaphore.signal() // Signal the semaphore to resume execution
        }.resume()
        
        semaphore.wait() // Wait for the network task to complete
        
        if redirectedURLString?.contains("voe.sx") == true {
            return voeUrlHandler(url: URL(string: redirectedURLString!)!)
        }
        else {
            return redirectedURLString
        }

    }

    /// Voe uses a custom handler to extract the video URL from the page
    /// The site uses windows.location.href to redirect to the video page, usally another domain but with the same path
    /// The replacement URL is hardcoded right now TODO: Make it dynamic
    func voeUrlHandler(url: URL) -> String? {
        
        let urlString = url.absoluteString
        
        // Check if the URL is a voe.sx URL
        guard urlString.contains("voe.sx") else {
            Logger.shared.log("Not a voe.sx URL")
            return nil
        }
        
        // Extract the path from the URL and append it to the hardcoded replacement URL
        // Example: https://voe.sx/e/1234567 -> /e/1234567
        let hardcodedURL = "https://sandratableother.com"
        let finishedUrl = urlString.replacingOccurrences(of: "https://voe.sx", with: hardcodedURL)
        
        return finishedUrl
    }
    
}

/// Custom handler to handle HTTP redirections and prevent them
class RedirectHandler: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
