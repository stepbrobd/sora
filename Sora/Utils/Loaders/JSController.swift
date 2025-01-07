//
//  JSController.swift
//  Sora
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
    
    func fetchSearchResults(keyword: String, module: ScrapingModule, completion: @escaping ([SearchItem]) -> Void) {
        let searchUrl = module.metadata.searchBaseUrl.replacingOccurrences(of: "%s", with: keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        
        guard let url = URL(string: searchUrl) else {
            completion([])
            return
        }
        
        URLSession.custom.dataTask(with: url) { [weak self] data, _, error in
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
                let resultItems = results.map { item in
                    SearchItem(
                        title: item["title"] ?? "",
                        imageUrl: item["image"] ?? "",
                        href: item["href"] ?? ""
                    )
                }
                DispatchQueue.main.async {
                    completion(resultItems)
                }
            } else {
                print("Failed to parse results")
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
    }
    
    func fetchDetails(url: String, completion: @escaping ([MediaItem]) -> Void) {
        guard let url = URL(string: url) else {
            completion([])
            return
        }
        
        URLSession.custom.dataTask(with: url) { [weak self] data, _, error in
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
            
            if let parseFunction = self.context.objectForKeyedSubscript("extractDetails"),
               let results = parseFunction.call(withArguments: [html]).toArray() as? [[String: String]] {
                let resultItems = results.map { item in
                    MediaItem(
                        description: item["description"] ?? "",
                        aliases: item["aliases"] ?? "",
                        airdate: item["airdate"] ?? ""
                    )
                }
                DispatchQueue.main.async {
                    completion(resultItems)
                }
            } else {
                print("Failed to parse results")
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
    }
}
