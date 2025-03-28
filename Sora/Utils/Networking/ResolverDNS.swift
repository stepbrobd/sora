//
//  ResolverDNS.swift
//  Sulfur
//
//  Created by seiike on 28/03/2025.
//

import Foundation
import Network

// MARK: - DNS Provider Enum

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

// MARK: - DNS Resolver Errors

enum DNSResolverError: Error {
    case invalidResponse
    case noAnswer
    case connectionError(String)
    case timeout
}

// MARK: - CustomDNSResolver Class

class CustomDNSResolver {
    
    /// Returns an array of DNS servers.
    /// If a custom provider ("Custom") is selected in UserDefaults, it returns the custom primary and secondary values;
    /// otherwise, it falls back to the default provider's servers.
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
    
    /// Resolves the provided hostname by sending a DNS query over UDP.
    /// - Parameters:
    ///   - hostname: The hostname to resolve.
    ///   - timeout: How long to wait for a response (default 5 seconds).
    ///   - completion: A closure called with the result: a list of IPv4 addresses or an error.
    func resolve(hostname: String, timeout: TimeInterval = 5.0, completion: @escaping (Result<[String], Error>) -> Void) {
        // Use the first DNS server from our list
        guard let dnsServer = dnsServers.first else {
            completion(.failure(DNSResolverError.connectionError("No DNS server available")))
            return
        }
        
        let port: NWEndpoint.Port = 53
        let queryID = UInt16.random(in: 0...UInt16.max)
        
        guard let queryData = buildDNSQuery(hostname: hostname, queryID: queryID) else {
            completion(.failure(DNSResolverError.connectionError("Failed to build DNS query")))
            return
        }
        
        // Create a new UDP connection
        let connection = NWConnection(host: NWEndpoint.Host(dnsServer), port: port, using: .udp)
        
        // Track connection state manually
        var localState = NWConnection.State.setup
        
        connection.stateUpdateHandler = { [weak self] newState in
            localState = newState
            switch newState {
            case .ready:
                // Send the DNS query
                connection.send(content: queryData, completion: .contentProcessed({ error in
                    if let error = error {
                        connection.cancel()
                        completion(.failure(DNSResolverError.connectionError(error.localizedDescription)))
                    } else {
                        // Receive the DNS response
                        self?.receiveDNSResponse(connection: connection,
                                                 expectedQueryID: queryID,
                                                 completion: completion)
                    }
                }))
            case .failed(let error):
                connection.cancel()
                completion(.failure(DNSResolverError.connectionError(error.localizedDescription)))
            default:
                break
            }
        }
        
        // Start the connection
        connection.start(queue: DispatchQueue.global())
        
        // Implement a timeout for the query using a switch on localState
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            switch localState {
            case .failed(_), .cancelled:
                // Already failed or canceled; do nothing
                break
            default:
                // Not failed or canceled => consider it timed out
                connection.cancel()
                completion(.failure(DNSResolverError.timeout))
            }
        }
    }
    
    // MARK: - Receiving and Parsing
    
    private func receiveDNSResponse(connection: NWConnection,
                                    expectedQueryID: UInt16,
                                    completion: @escaping (Result<[String], Error>) -> Void) {
        connection.receiveMessage { [weak self] data, _, _, error in
            connection.cancel()
            
            if let error = error {
                completion(.failure(DNSResolverError.connectionError(error.localizedDescription)))
                return
            }
            guard let data = data else {
                completion(.failure(DNSResolverError.invalidResponse))
                return
            }
            
            if let ips = self?.parseDNSResponse(data: data, queryID: expectedQueryID), !ips.isEmpty {
                completion(.success(ips))
            } else {
                completion(.failure(DNSResolverError.noAnswer))
            }
        }
    }
    
    // MARK: - DNS Query Construction
    
    /// Constructs a DNS query packet for the given hostname.
    /// - Parameters:
    ///   - hostname: The hostname to resolve.
    ///   - queryID: A randomly generated query identifier.
    /// - Returns: A Data object representing the DNS query.
    private func buildDNSQuery(hostname: String, queryID: UInt16) -> Data? {
        var data = Data()
        
        // Header: ID (2 bytes)
        data.append(contentsOf: withUnsafeBytes(of: queryID.bigEndian, Array.init))
        
        // Flags: standard query with recursion desired (0x0100)
        let flags: UInt16 = 0x0100
        data.append(contentsOf: withUnsafeBytes(of: flags.bigEndian, Array.init))
        
        // QDCOUNT = 1
        let qdcount: UInt16 = 1
        data.append(contentsOf: withUnsafeBytes(of: qdcount.bigEndian, Array.init))
        
        // ANCOUNT = 0, NSCOUNT = 0, ARCOUNT = 0
        let zero: UInt16 = 0
        data.append(contentsOf: withUnsafeBytes(of: zero.bigEndian, Array.init)) // ANCOUNT
        data.append(contentsOf: withUnsafeBytes(of: zero.bigEndian, Array.init)) // NSCOUNT
        data.append(contentsOf: withUnsafeBytes(of: zero.bigEndian, Array.init)) // ARCOUNT
        
        // Question section:
        // QNAME: Encode hostname by splitting into labels.
        let labels = hostname.split(separator: ".")
        for label in labels {
            guard let labelData = label.data(using: .utf8) else {
                return nil
            }
            data.append(UInt8(labelData.count))
            data.append(labelData)
        }
        // Terminate QNAME with zero byte.
        data.append(0)
        
        // QTYPE: A record (1)
        let qtype: UInt16 = 1
        data.append(contentsOf: withUnsafeBytes(of: qtype.bigEndian, Array.init))
        
        // QCLASS: IN (1)
        let qclass: UInt16 = 1
        data.append(contentsOf: withUnsafeBytes(of: qclass.bigEndian, Array.init))
        
        return data
    }
    
    // MARK: - DNS Response Parsing
    
    /// Parses the DNS response packet and extracts IPv4 addresses from A record answers.
    /// - Parameters:
    ///   - data: The DNS response data.
    ///   - queryID: The expected query identifier.
    /// - Returns: An array of IPv4 address strings, or nil if parsing fails.
    private func parseDNSResponse(data: Data, queryID: UInt16) -> [String]? {
        // Ensure the response is at least long enough for a header.
        guard data.count >= 12 else { return nil }
        
        // ID is the first 2 bytes
        let responseID = data.subdata(in: 0..<2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
        guard responseID == queryID else { return nil }
        
        // ANCOUNT is at offset 6.
        let ancount = data.subdata(in: 6..<8).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
        if ancount == 0 { return nil }
        
        // Skip the header and question section.
        var offset = 12
        // Skip QNAME
        while offset < data.count && data[offset] != 0 {
            offset += Int(data[offset]) + 1
        }
        offset += 1 // Skip the terminating zero.
        
        // Skip QTYPE (2 bytes) and QCLASS (2 bytes)
        offset += 4
        
        var ips: [String] = []
        
        // Loop through answer records.
        for _ in 0..<ancount {
            if offset + 12 > data.count { break }
            offset += 2 // Skip NAME (pointer)
            let type = data.subdata(in: offset..<(offset+2)).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
            offset += 2 // TYPE
            offset += 2 // CLASS
            offset += 4 // TTL
            let rdlength = data.subdata(in: offset..<(offset+2)).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
            offset += 2
            
            // If the record is an A record and the length is 4 bytes, extract the IPv4 address.
            if type == 1 && rdlength == 4 && offset + 4 <= data.count {
                let ipBytes = data.subdata(in: offset..<(offset+4))
                let ip = ipBytes.map { String($0) }.joined(separator: ".")
                ips.append(ip)
            }
            offset += Int(rdlength)
        }
        
        return ips
    }
}
