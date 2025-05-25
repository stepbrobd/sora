//
//  BackupData.swift
//  Sulfur
//
//  Created by Francesco on 25/05/25.
//

import Foundation
import SwiftUI

struct BackupData: Codable {
    let version: String
    let timestamp: Date
    let userData: [String: Any]
    
    init(userData: [String: Any]) {
        self.version = "1.0"
        self.timestamp = Date()
        self.userData = userData
    }
    
    enum CodingKeys: String, CodingKey {
        case version, timestamp, userData
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        let userDataContainer = try container.nestedContainer(keyedBy: DynamicKey.self, forKey: .userData)
        var userData: [String: Any] = [:]
        
        for key in userDataContainer.allKeys {
            userData[key.stringValue] = try userDataContainer.decode(AnyCodable.self, forKey: key).value
        }
        
        self.userData = userData
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(timestamp, forKey: .timestamp)
        
        var userDataContainer = container.nestedContainer(keyedBy: DynamicKey.self, forKey: .userData)
        for (key, value) in userData {
            let dynamicKey = DynamicKey(stringValue: key)!
            try userDataContainer.encode(AnyCodable(value), forKey: dynamicKey)
        }
    }
}

struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = String(intValue)
    }
}

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported type"))
        }
    }
}
