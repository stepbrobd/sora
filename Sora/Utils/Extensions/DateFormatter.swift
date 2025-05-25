//
//  DateFormatter.swift
//  Sulfur
//
//  Created by Francesco on 25/05/25.
//

import Foundation

extension DateFormatter {
    static let backupFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}
