//
//  DNSConfiguration.swift
//  Sulfur
//
//  Created by Francesco on 14/06/25.
//

import Network
import Foundation

enum DNSServer: String, CaseIterable {
    case cloudflare = "1.1.1.1"
    case cloudflareSecondary = "1.0.0.1"
    case adGuard = "94.140.14.14"
    case adGuardSecondary = "94.140.15.15"
    case google = "8.8.8.8"
    case googleSecondary = "8.8.4.4"
    
    static var current: [DNSServer] = [.cloudflare, .cloudflareSecondary]
}

class DNSConfiguration {
    static let shared = DNSConfiguration()
    
    private init() {}
    
    func configureDNS(for session: URLSession) -> URLSession {
        let configuration = (session.configuration.copy() as! URLSessionConfiguration)
        
        let proxyDict: [AnyHashable: Any] = [
            kCFProxyTypeKey: kCFProxyTypeHTTPS,
            kCFProxyHostNameKey: DNSServer.current[0].rawValue,
            kCFProxyPortNumberKey: 443,
            kCFProxyUsernameKey: "",
            kCFProxyPasswordKey: ""
        ]
        
        configuration.connectionProxyDictionary = proxyDict
        
        return URLSession(configuration: configuration, delegate: session.delegate, delegateQueue: session.delegateQueue)
    }
    
    func setDNSServer(_ servers: [DNSServer]) {
        DNSServer.current = servers
        URLSession.shared.invalidateAndCancel()
    }
}
