//
//  SettingsViewDNS.swift
//  Sulfur
//
//  Created by Francesco on 14/06/25.
//

import SwiftUI

fileprivate struct SettingsSection<Content: View>: View {
    let title: String
    let footer: String?
    let content: Content
    
    init(title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.footnote)
                .foregroundStyle(.gray)
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                content
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.accentColor.opacity(0.3), location: 0),
                                .init(color: Color.accentColor.opacity(0), location: 1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .padding(.horizontal, 20)
            
            if let footer = footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
        }
    }
}

struct SettingsViewDNS: View {
    @State private var selectedDNS: [DNSServer] = DNSServer.current
    
    var body: some View {
        List {
            SettingsSection(title: "DNS Server") {
                ForEach(DNSServer.allCases.filter { $0.rawValue.hasSuffix(".14") || $0.rawValue.hasSuffix(".1") || $0.rawValue.hasSuffix(".8") }, id: \.self) { server in
                    Button(action: {
                        if let index = selectedDNS.firstIndex(of: server) {
                            selectedDNS.remove(at: index)
                        } else {
                            selectedDNS = [server]
                            if server == .cloudflare {
                                selectedDNS.append(.cloudflareSecondary)
                            } else if server == .adGuard {
                                selectedDNS.append(.adGuardSecondary)
                            } else if server == .google {
                                selectedDNS.append(.googleSecondary)
                            }
                        }
                        DNSConfiguration.shared.setDNSServer(selectedDNS)
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(server.rawValue)
                                Text(serverDescription(server))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            if selectedDNS.contains(server) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            
            Section(footer: Text("Using custom DNS servers can help protect your privacy and potentially block ads. Changes take effect immediately.")) {}
        }
        .navigationTitle("DNS Settings")
    }
    
    private func serverDescription(_ server: DNSServer) -> String {
        switch server {
        case .cloudflare:
            return "Cloudflare (Fast & Private)"
        case .adGuard:
            return "AdGuard (Ad Blocking)"
        case .google:
            return "Google (Reliable)"
        default:
            return ""
        }
    }
}
