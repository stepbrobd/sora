//
//  ModuleAdditionSettingsView.swift
//  Sora
//
//  Created by Francesco on 01/02/25.
//

import SwiftUI
import Kingfisher

struct ModuleAdditionSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var moduleManager: ModuleManager
    @Environment(\.colorScheme) var colorScheme
    
    @State private var moduleMetadata: ModuleMetadata?
    @State private var isLoading = false
    @State private var errorMessage: String?
    var moduleUrl: String
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    colorScheme == .dark ? Color.black : Color.white,
                    Color.accentColor.opacity(0.08)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(10)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(Circle())
                            .circularGradientOutline()
                    }
                    Spacer()
                    Text("Add Module")
                        .font(.largeTitle.bold())
                        .foregroundColor(.primary)
                    Spacer()
                    Color.clear.frame(width: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                
                ScrollView {
                    VStack(spacing: 28) {
                        if let metadata = moduleMetadata {
                            VStack(spacing: 18) {
                                KFImage(URL(string: metadata.iconUrl))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 110, height: 110)
                                    .clipShape(Circle())
                                    .shadow(radius: 6)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.accentColor, lineWidth: 2)
                                    )
                                    .padding(.top, 10)
                                
                                Text(metadata.sourceName)
                                    .font(.title2.bold())
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 14) {
                                    KFImage(URL(string: metadata.author.icon))
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 48, height: 48)
                                        .clipShape(Circle())
                                        .shadow(radius: 2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(metadata.author.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("Author")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color(.systemGray6).opacity(colorScheme == .dark ? 0.2 : 0.7))
                                )
                                
                                VStack(spacing: 0) {
                                    InfoRow(title: "Version", value: metadata.version)
                                    Divider().padding(.horizontal, 8)
                                    InfoRow(title: "Language", value: metadata.language)
                                    Divider().padding(.horizontal, 8)
                                    InfoRow(title: "Quality", value: metadata.quality)
                                    Divider().padding(.horizontal, 8)
                                    InfoRow(title: "Stream Typed", value: metadata.streamType)
                                    Divider().padding(.horizontal, 8)
                                    InfoRow(title: "Base URL", value: metadata.baseUrl)
                                        .onLongPressGesture {
                                            UIPasteboard.general.string = metadata.baseUrl
                                            DropManager.shared.showDrop(title: "Copied to Clipboard", subtitle: "", duration: 1.0, icon: UIImage(systemName: "doc.on.clipboard.fill"))
                                        }
                                    Divider().padding(.horizontal, 8)
                                    InfoRow(title: "Script URL", value: metadata.scriptUrl)
                                        .onLongPressGesture {
                                            UIPasteboard.general.string = metadata.scriptUrl
                                            DropManager.shared.showDrop(title: "Copied to Clipboard", subtitle: "", duration: 1.0, icon: UIImage(systemName: "doc.on.clipboard.fill"))
                                        }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color(.systemGray6).opacity(colorScheme == .dark ? 0.18 : 0.8))
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                        } else if isLoading {
                            VStack(spacing: 20) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Loading module information...")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxHeight: .infinity)
                            .padding(.top, 100)
                        } else if let errorMessage = errorMessage {
                            VStack(spacing: 20) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.red)
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxHeight: .infinity)
                            .padding(.top, 100)
                        }
                    }
                    .padding(.bottom, 30)
                }
                
                VStack(spacing: 10) {
                    Button(action: addModule) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Module")
                        }
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.accentColor.opacity(0.95),
                                    Color.accentColor.opacity(0.7)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                        )
                        .shadow(color: Color.accentColor.opacity(0.18), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 20)
                    }
                    .disabled(isLoading || moduleMetadata == nil)
                    .opacity(isLoading ? 0.6 : 1)
                    
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Text("Cancel")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .onAppear(perform: fetchModuleMetadata)
    }
    
    private func fetchModuleMetadata() {
        isLoading = true
        errorMessage = nil
        
        Task {
            guard let url = URL(string: moduleUrl) else {
                await MainActor.run {
                    self.errorMessage = "Invalid URL"
                    self.isLoading = false
                    Logger.shared.log("Failed to open add module ui with url: \(moduleUrl)", type: "Error")
                }
                return
            }
            do {
                let (data, _) = try await URLSession.custom.data(from: url)
                let metadata = try JSONDecoder().decode(ModuleMetadata.self, from: data)
                await MainActor.run {
                    self.moduleMetadata = metadata
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to fetch module: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func addModule() {
        isLoading = true
        Task {
            do {
                let _ = try await moduleManager.addModule(metadataUrl: moduleUrl)
                await MainActor.run {
                    isLoading = false
                    DropManager.shared.showDrop(title: "Module Added", subtitle: "Click it to select it.", duration: 2.0, icon: UIImage(systemName:"gear.badge.checkmark"))
                    self.presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if (error as NSError).domain == "Module already exists" {
                        errorMessage = "Module already exists"
                    } else {
                        errorMessage = "Failed to add module: \(error.localizedDescription)"
                    }
                    Logger.shared.log("Failed to add module: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.vertical, 6)
    }
}
