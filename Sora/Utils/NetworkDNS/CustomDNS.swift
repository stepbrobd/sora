//
//  CustomDNS.swift
//  Sora
//
//  Created by Seiike on 26/03/25.
//
// fuck region restrictions

import Foundation
import Network

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
    
    static var current: DNSProvider {
        get {
            let raw = UserDefaults.standard.string(forKey: "SelectedDNSProvider") ?? DNSProvider.cloudflare.rawValue
            return DNSProvider(rawValue: raw) ?? .cloudflare
        }
        set {
            UserDefaults.standard.setValue(newValue.rawValue, forKey: "SelectedDNSProvider")
        }
    }
}

class CustomDNSResolver {
    // Use custom DNS servers if "Custom" is selected; otherwise, fall back to the default provider's servers.
    var dnsServers: [String] {
        if let provider = UserDefaults.standard.string(forKey: "CustomDNSProvider"),
           provider == "Custom" {
            let primary = UserDefaults.standard.string(forKey: "customPrimaryDNS") ?? ""
            let secondary = UserDefaults.standard.string(forKey: "customSecondaryDNS") ?? ""
            var servers = [String]()
            if !primary.isEmpty { servers.append(primary) }
            if !secondary.isEmpty { servers.append(secondary) }
            if !servers.isEmpty {
                return servers
            }
        }
        return DNSProvider.current.servers
    }
    
    var dnsServerIP: String {
        return dnsServers.first ?? "1.1.1.1"
    }
    
    func buildDNSQuery(for host: String) -> (Data, UInt16) {
        var data = Data()
        let queryID = UInt16.random(in: 0...UInt16.max)
        data.append(UInt8(queryID >> 8))
        data.append(UInt8(queryID & 0xFF))
        data.append(contentsOf: [0x01, 0x00])
        data.append(contentsOf: [0x00, 0x01])
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        let labels = host.split(separator: ".")
        for label in labels {
            if let labelData = label.data(using: .utf8) {
                data.append(UInt8(labelData.count))
                data.append(labelData)
            }
        }
        data.append(0)
        data.append(contentsOf: [0x00, 0x01])
        data.append(contentsOf: [0x00, 0x01])
        return (data, queryID)
    }
    
    func parseDNSResponse(_ data: Data, queryID: UInt16) -> [String] {
        // Existing implementation remains unchanged.
        var ips = [String]()
        var offset = 0
        func readUInt16() -> UInt16? {
            guard offset + 2 <= data.count else { return nil }
            let value = (UInt16(data[offset]) << 8) | UInt16(data[offset+1])
            offset += 2
            return value
        }
        func readUInt32() -> UInt32? {
            guard offset + 4 <= data.count else { return nil }
            let value = (UInt32(data[offset]) << 24) | (UInt32(data[offset+1]) << 16) | (UInt32(data[offset+2]) << 8) | UInt32(data[offset+3])
            offset += 4
            return value
        }
        guard data.count >= 12 else { return [] }
        let responseID = (UInt16(data[0]) << 8) | UInt16(data[1])
        if responseID != queryID { return [] }
        offset = 2
        offset += 2
        guard let qdCount = readUInt16() else { return [] }
        guard let anCount = readUInt16() else { return [] }
        offset += 4
        for _ in 0..<qdCount {
            while offset < data.count && data[offset] != 0 {
                let length = Int(data[offset])
                offset += 1 + length
            }
            offset += 1
            offset += 4
        }
        for _ in 0..<anCount {
            if offset < data.count {
                let nameByte = data[offset]
                if nameByte & 0xC0 == 0xC0 {
                    offset += 2
                } else {
                    while offset < data.count && data[offset] != 0 {
                        let length = Int(data[offset])
                        offset += 1 + length
                    }
                    offset += 1
                }
            }
            guard let type = readUInt16(), let _ = readUInt16() else { break }
            let _ = readUInt32()
            guard let dataLen = readUInt16() else { break }
            if type == 1 && dataLen == 4 {
                guard offset + 4 <= data.count else { break }
                let ipBytes = data[offset..<offset+4]
                let ip = ipBytes.map { String($0) }.joined(separator: ".")
                ips.append(ip)
            }
            offset += Int(dataLen)
        }
        return ips
    }
    
    func resolve(host: String, completion: @escaping (Result<[String], Error>) -> Void) {
        let dnsServer = self.dnsServerIP
        guard let port = NWEndpoint.Port(rawValue: 53) else {
            completion(.failure(NSError(domain: "CustomDNS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid port"])))
            return
        }
        let connection = NWConnection(host: NWEndpoint.Host(dnsServer), port: port, using: .udp)
        connection.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                let (queryData, queryID) = self.buildDNSQuery(for: host)
                connection.send(content: queryData, completion: .contentProcessed({ error in
                    if let error = error {
                        completion(.failure(error))
                        connection.cancel()
                    } else {
                        connection.receive(minimumIncompleteLength: 1, maximumLength: 512) { content, _, _, error in
                            if let error = error {
                                completion(.failure(error))
                            } else if let content = content {
                                let ips = self.parseDNSResponse(content, queryID: queryID)
                                if !ips.isEmpty {
                                    completion(.success(ips))
                                } else {
                                    completion(.failure(NSError(domain: "CustomDNS", code: 2, userInfo: [NSLocalizedDescriptionKey: "No A records found"])))
                                }
                            }
                            connection.cancel()
                        }
                    }
                }))
            case .failed(let error):
                completion(.failure(error))
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: DispatchQueue.global())
    }
}


class CustomURLProtocol: URLProtocol {
    static let resolver = CustomDNSResolver()
    override class func canInit(with request: URLRequest) -> Bool {
        return URLProtocol.property(forKey: "Handled", in: request) == nil
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    override func startLoading() {
        guard let url = request.url, let host = url.host else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "CustomDNS", code: -1, userInfo: nil))
            return
        }
        CustomURLProtocol.resolver.resolve(host: host) { result in
            switch result {
            case .success(let ips):
                guard let ip = ips.first,
                      var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                    self.client?.urlProtocol(self, didFailWithError: NSError(domain: "CustomDNS", code: -2, userInfo: nil))
                    return
                }
                components.host = ip
                guard let ipURL = components.url else {
                    self.client?.urlProtocol(self, didFailWithError: NSError(domain: "CustomDNS", code: -3, userInfo: nil))
                    return
                }
                guard let mutableRequest = (self.request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
                    self.client?.urlProtocol(self, didFailWithError: NSError(domain: "CustomDNS", code: -4, userInfo: nil))
                    return
                }
                mutableRequest.url = ipURL
                mutableRequest.setValue(host, forHTTPHeaderField: "Host")
                URLProtocol.setProperty(true, forKey: "Handled", in: mutableRequest)
                let finalRequest = mutableRequest as URLRequest
                let session = URLSession.customDNS
                let task = session.dataTask(with: finalRequest) { data, response, error in
                    if let data = data, let response = response {
                        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                        self.client?.urlProtocol(self, didLoad: data)
                        self.client?.urlProtocolDidFinishLoading(self)
                    } else if let error = error {
                        self.client?.urlProtocol(self, didFailWithError: error)
                    }
                }
                task.resume()
            case .failure(let error):
                self.client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }
    override func stopLoading() {}
}

class InsecureSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust, let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

func registerCustomDNSGlobally() {
    let config = URLSessionConfiguration.default
    var protocols = config.protocolClasses ?? []
    protocols.insert(CustomURLProtocol.self, at: 0)
    config.protocolClasses = protocols
    URLSessionConfiguration.default.protocolClasses = protocols
    URLSessionConfiguration.ephemeral.protocolClasses = protocols
    URLSessionConfiguration.background(withIdentifier: "CustomDNSBackground").protocolClasses = protocols
}
