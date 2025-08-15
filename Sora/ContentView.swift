//
//  ContentView.swift
//  Sora
//
//  Created by Francesco on 06/01/25.
//

import SwiftUI

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(LibraryManager())
            .environmentObject(ModuleManager())
            .environmentObject(Settings())
    }
}

struct ContentView: View {
    @AppStorage("useNativeTabBar") private var useNativeTabBar: Bool = false
    @State var selectedTab: Int = 0
    @State var lastTab: Int = 0
    @State private var searchQuery: String = ""
    @State private var shouldShowTabBar: Bool = true
    @State private var tabBarOffset: CGFloat = 0
    @State private var tabBarVisible: Bool = true
    @State private var lastHideTime: Date = Date()
    
    let tabs: [TabItem] = [
        TabItem(icon: "square.stack", title: NSLocalizedString("LibraryTab", comment: "")),
        TabItem(icon: "arrow.down.circle", title: NSLocalizedString("DownloadsTab", comment: "")),
        TabItem(icon: "gearshape", title: NSLocalizedString("SettingsTab", comment: "")),
        TabItem(icon: "magnifyingglass", title: NSLocalizedString("SearchTab", comment: ""))
    ]
    
    private func tabView(for index: Int) -> some View {
        switch index {
        case 1: return AnyView(DownloadView())
        case 2: return AnyView(SettingsView())
        case 3: return AnyView(SearchView(searchQuery: $searchQuery))
        default: return AnyView(LibraryView())
        }
    }
    
    var body: some View {
        if #available(iOS 26, *), useNativeTabBar == true {
            TabView {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, item in
                    tabView(for: index)
                        .tabItem {
                            Label(item.title, systemImage: item.icon)
                        }
                }
            }
            //.searchable(text: $searchQuery)
        } else {
            ZStack(alignment: .bottom) {
                ZStack {
                    tabView(for: selectedTab)
                        .id(selectedTab)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: selectedTab)
                }
                .onPreferenceChange(TabBarVisibilityKey.self) { shouldShowTabBar = $0 }
                
                if shouldShowTabBar {
                    TabBar(
                        tabs: tabs,
                        selectedTab: $selectedTab
                    )
                    .opacity(shouldShowTabBar && tabBarVisible ? 1 : 0)
                    .offset(y: tabBarVisible ? 0 : 120)
                    .animation(.spring(response: 0.15, dampingFraction: 0.7), value: tabBarVisible)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .padding(.bottom, -20)
            .onAppear {
                setupNotificationObservers()
            }
            .onDisappear {
                removeNotificationObservers()
            }
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .hideTabBar,
            object: nil,
            queue: .main
        ) { _ in
            lastHideTime = Date()
            tabBarVisible = false
        }
        
        NotificationCenter.default.addObserver(
            forName: .showTabBar,
            object: nil,
            queue: .main
        ) { _ in
            let timeSinceHide = Date().timeIntervalSince(lastHideTime)
            if timeSinceHide > 0.2 {
                tabBarVisible = true
            }
        }
    }
    
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self, name: .hideTabBar, object: nil)
        NotificationCenter.default.removeObserver(self, name: .showTabBar, object: nil)
    }
}

struct TabBarVisibilityKey: PreferenceKey {
    static var defaultValue: Bool = true
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}
