//
//  OnBoardingView.swift
//  Sulfur
//
//  Created by Francesco on 25/03/25.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    
    @EnvironmentObject var settings: Settings
    
    private var totalPages: Int {
        onboardingScreens.count + 1
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            hasCompletedOnboarding = true
                            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        }
                    }) {
                        Text("Skip")
                            .foregroundColor(.accentColor)
                            .padding()
                    }
                }
                
                TabView(selection: $currentPage) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        if index < onboardingScreens.count {
                            OnboardingPageView(page: onboardingScreens[index])
                                .tag(index)
                        } else if index == onboardingScreens.count {
                            OnboardingCustomizeAppearanceView()
                                .tag(index)
                                .environmentObject(settings)
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                PageIndicatorView(currentPage: currentPage, totalPages: totalPages)
                    .padding(.vertical, 10)
                
                Spacer()
                
                HStack {
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation { currentPage -= 1 }
                        }) {
                            Text("Back")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding()
                    }
                    Spacer()
                    Button(action: {
                        withAnimation {
                            if currentPage == totalPages - 1 {
                                hasCompletedOnboarding = true
                                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                            } else {
                                currentPage += 1
                            }
                        }
                    }) {
                        Text(currentPage == totalPages - 1 ? "Get Started" : "Continue")
                    }
                    .buttonStyle(FilledButtonStyle())
                }
                .padding(.horizontal)
            }
        }
    }
}

struct PageIndicatorView: View {
    let currentPage: Int
    let totalPages: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Image(systemName: currentPage == index ? "circle.fill" : "circle")
                    .foregroundColor(currentPage == index ? .accentColor : .gray)
                    .font(.system(size: 10))
            }
        }
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: page.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 175, height: 175)
                .foregroundColor(.accentColor)
                .padding()
            
            Text(page.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
    }
}

struct OnboardingPage {
    let imageName: String
    let title: String
    let description: String
}

let onboardingScreens = [
    OnboardingPage(
        imageName: "puzzlepiece.fill",
        title: "Modular Web Scraping",
        description: "Sora is a powerful, open-source web scraping app that works exclusively with custom modules."
    ),
    OnboardingPage(
        imageName: "display",
        title: "Multi-Platform Support",
        description: "Enjoy Sora on iOS, iPadOS 15.0+ and macOS 12.0+. A flexible app for all your devices."
    ),
    OnboardingPage(
        imageName: "play.circle.fill",
        title: "Diverse Media Playback",
        description: "Stream content from Jellyfin/Plex servers or any module and play media in external players like VLC, Infuse, and nPlayer or directly with the Sora or iOS player"
    ),
    OnboardingPage(
        imageName: "lock.shield.fill",
        title: "Privacy First",
        description: "No subscriptions, no logins, no data collection. Sora prioritizes your privacy and will always be free and open source under the GPLv3.0 License."
    )
]

struct OnboardingCustomizeAppearanceView: View {
    @EnvironmentObject var settings: Settings
    
    @AppStorage("alwaysLandscape") private var isAlwaysLandscape = false
    
    @AppStorage("externalPlayer") private var externalPlayer: String = "Sora"
    private let mediaPlayers = ["Default", "VLC", "OutPlayer", "Infuse", "nPlayer", "Sora"]
    
    var body: some View {
        VStack {
            Text("Customize Sora")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
            
            VStack(spacing: 20) {
                SettingsSection(title: "Theme") {
                    ColorPicker("Accent Color", selection: $settings.accentColor)
                    
                    Picker("Appearance", selection: $settings.selectedAppearance) {
                        Text("System").tag(Appearance.system)
                        Text("Light").tag(Appearance.light)
                        Text("Dark").tag(Appearance.dark)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                SettingsSection(title: "Media Player") {
                    HStack {
                        Text("Media Player")
                        Spacer()
                        Menu(externalPlayer) {
                            ForEach(mediaPlayers, id: \.self) { provider in
                                Button(action: {
                                    externalPlayer = provider
                                }) {
                                    Text(provider)
                                }
                            }
                        }
                    }
                    
                    Toggle("Force Landscape", isOn: $isAlwaysLandscape)
                        .tint(.accentColor)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Text(title + ":")
                .font(.headline)
            
            content
            
            Divider()
        }
    }
}
