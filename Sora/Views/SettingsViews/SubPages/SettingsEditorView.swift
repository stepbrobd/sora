//
//  SettingsEditorView.swift
//  Sora
//
//  Created by Francesco on 03/01/25.
//

import SwiftUI

struct SettingsEditorView: View {
    @ObservedObject var modulesManager: ModulesManager
    @State private var jsonText: String = ""

    var body: some View {
        VStack {
            TextEditor(text: $jsonText)
                .padding()
                .onAppear {
                    if let data = try? JSONEncoder().encode(modulesManager.modules),
                       let jsonString = String(data: data, encoding: .utf8) {
                        jsonText = jsonString
                    }
                }
        }
        .navigationTitle("Editor")
        .navigationBarItems(trailing: Button("Save") {
            if let data = jsonText.data(using: .utf8),
               let modules = try? JSONDecoder().decode([ModuleStruct].self, from: data) {
                modulesManager.modules = modules
                modulesManager.saveModuleData()
            }
        })
    }
}