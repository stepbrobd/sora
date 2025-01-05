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
    
    func scrapeAnime(keyword: String, module: ScrapingModule, completion: @escaping ([AnimeItem]) -> Void) {
        let searchUrl = module.metadata.searchBaseUrl.replacingOccurrences(of: "%s", with: keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        
        guard let url = URL(string: searchUrl) else {
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
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
            
            if let parseFunction = self.context.objectForKeyedSubscript("parseHTML"),
               let results = parseFunction.call(withArguments: [html]).toArray() as? [[String: String]] {
                let animeItems = results.map { item in
                    AnimeItem(
                        title: item["title"] ?? "",
                        imageUrl: item["image"] ?? ""
                    )
                }
                DispatchQueue.main.async {
                    completion(animeItems)
                }
            } else {
                print("Failed to parse results")
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
    }
}
