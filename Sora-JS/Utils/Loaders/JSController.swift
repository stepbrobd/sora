//
//  JSController.swift
//  Sora-JS
//
//  Created by Francesco on 05/01/25.
//

import JavaScriptCore

class JSController: ObservableObject {
    private var context: JSContext
    
    init() {
        self.context = JSContext()
        setupContext()
    }
    
    private func setupContext() {
        let logFunction: @convention(block) (String) -> Void = { message in
            print("JavaScript log: \(message)")
        }
        context.setObject(logFunction, forKeyedSubscript: "log" as NSString)
    }
    
    func loadScript(_ script: String) {
        context = JSContext()
        setupContext()
        context.evaluateScript(script)
    }
    
    func fetchSearchResults(keyword: String, module: ScrapingModule, completion: @escaping ([MediaItem]) -> Void) {
        let searchUrl = module.metadata.searchBaseUrl.replacingOccurrences(of: "%s", with: keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        
        guard let url = URL(string: searchUrl) else {
            completion([])
            return
        }
        
        URLSession.custom.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Network error: \(error)")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                print("Failed to decode HTML")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            if let parseFunction = self.context.objectForKeyedSubscript("searchResults"),
               let results = parseFunction.call(withArguments: [html]).toArray() as? [[String: String]] {
                let mediaItems = results.map { item in
                    MediaItem(
                        title: item["title"] ?? "",
                        imageUrl: item["image"] ?? "",
                        href: item["href"] ?? ""
                    )
                }
                DispatchQueue.main.async {
                    completion(mediaItems)
                }
            } else {
                print("Failed to parse results")
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
    }
    
    func fetchInfoContent(href: String, module: ScrapingModule, completion: @escaping ([MediaItem]) -> Void) {
        guard let url = URL(string: href) else {
            completion([])
            return
        }
        
        URLSession.custom.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Network error: \(error)")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                print("Failed to decode HTML")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            if let parseFunction = self.context.objectForKeyedSubscript("fetchInfo"),
               let results = parseFunction.call(withArguments: [html]).toArray() as? [[String: String]] {
                let mediaItems = results.map { item in
                    MediaItem(
                        title: item["title"] ?? "",
                        imageUrl: item["image"] ?? "",
                        href: item["href"] ?? ""
                    )
                }
                DispatchQueue.main.async {
                    completion(mediaItems)
                }
            } else {
                print("Failed to parse results")
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
    }
}
