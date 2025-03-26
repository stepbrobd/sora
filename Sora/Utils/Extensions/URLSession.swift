//
//  URLSession.swift
//  Sora-JS
//
//  Created by Francesco on 05/01/25.
//

import Network
import Foundation

enum DNSProvider: String, CaseIterable, Hashable {
    case cloudflare = "Cloudflare"
    case google = "Google"
    case openDNS = "OpenDNS"
    case quad9 = "Quad9"
    case adGuard = "AdGuard"
    case cleanbrowsing = "CleanBrowsing"
    case controld = "ControlD"
    
    var servers: [String] {
        switch self {
        case .cloudflare:
            return ["1.1.1.1", "1.0.0.1"]
        case .google:
            return ["8.8.8.8", "8.8.4.4"]
        case .openDNS:
            return ["208.67.222.222", "208.67.220.220"]
        case .quad9:
            return ["9.9.9.9", "149.112.112.112"]
        case .adGuard:
            return ["94.140.14.14", "94.140.15.15"]
        case .cleanbrowsing:
            return ["185.228.168.168", "185.228.169.168"]
        case .controld:
            return ["76.76.2.0", "76.76.10.0"]
        }
    }
}

extension URLSession {
    private static let dnsSelectorKey = "CustomDNSProvider"
    
    static var currentDNSProvider: DNSProvider {
        get {
            guard let savedProviderRawValue = UserDefaults.standard.string(forKey: dnsSelectorKey) else {
                UserDefaults.standard.set(DNSProvider.cloudflare.rawValue, forKey: dnsSelectorKey)
                return .cloudflare
            }
            
            return DNSProvider(rawValue: savedProviderRawValue) ?? .cloudflare
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: dnsSelectorKey)
        }
    }
    
    static let userAgents = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:123.0) Gecko/20100101 Firefox/123.0",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:122.0) Gecko/20100101 Firefox/122.0",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 Edg/122.0.2365.92",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36 Edg/121.0.2277.128",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_3_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_2_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14.3; rv:123.0) Gecko/20100101 Firefox/123.0",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14.2; rv:122.0) Gecko/20100101 Firefox/122.0",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Mozilla/5.0 (X11; Linux x86_64; rv:123.0) Gecko/20100101 Firefox/123.0",
        "Mozilla/5.0 (X11; Linux x86_64; rv:122.0) Gecko/20100101 Firefox/122.0",
        "Mozilla/5.0 (Linux; Android 14; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.6261.105 Mobile Safari/537.36",
        "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.6261.105 Mobile Safari/537.36",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPad; CPU OS 17_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (Android 14; Mobile; rv:123.0) Gecko/123.0 Firefox/123.0",
        "Mozilla/5.0 (Android 13; Mobile; rv:122.0) Gecko/122.0 Firefox/122.0"
    ]
    
    static var randomUserAgent: String {
        userAgents.randomElement() ?? userAgents[0]
    }
    
    static var custom: URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = [
            "User-Agent": randomUserAgent
        ]
        return URLSession(configuration: configuration)
    }
    
    static var cloudflareCustom: URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = [
            "User-Agent": randomUserAgent
        ]
        
        let dnsServers = currentDNSProvider.servers
        
        let dnsSettings: [AnyHashable: Any] = [
            "DNSSettings": [
                "ServerAddresses": dnsServers
            ]
        ]
        
        configuration.connectionProxyDictionary = dnsSettings
        return URLSession(configuration: configuration)
    }
}
