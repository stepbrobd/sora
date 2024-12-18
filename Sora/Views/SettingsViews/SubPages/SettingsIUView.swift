//
//  SettingsIUView.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI

struct SettingsIUView: View {
    @AppStorage("listSearch") private var isListSearchEnabled: Bool = false
    
    var body: some View {
        Form {
            Section(header: Text("Search")) {
                Toggle("List Search Style", isOn: $isListSearchEnabled)
                    .tint(.accentColor)
            }
        }
        .navigationTitle("Interface Preference")
    }
}
