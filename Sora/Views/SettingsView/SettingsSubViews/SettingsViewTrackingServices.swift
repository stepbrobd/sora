//
//  SettingsViewTrackingServices.swift
//  Sulfur
//
//  Created by Francesco on 05/03/25.
//

import SwiftUI
import Kingfisher

struct SettingsViewTrackingServices: View {
    @AppStorage("trackingService") private var trackingService: String = "AniList"
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        Form {
            Section(header: Text("Tracking Service")) {
                HStack {
                    Text("Service")
                    Spacer()
                    Menu {
                        Button(action: { trackingService = "AniList" }) {
                            HStack {
                                KFImage(URL(string: "https://avatars.githubusercontent.com/u/18018524?s=280&v=4"))
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text("AniList")
                            }
                        }
                        Button(action: { trackingService = "TMDB" }) {
                            HStack {
                                KFImage(URL(string: "https://pbs.twimg.com/profile_images/1243623122089041920/gVZIvphd_400x400.jpg"))
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text("TMDB")
                            }
                        }
                    } label: {
                        HStack {
                            KFImage(URL(string: trackingService == "TMDB" ? "https://pbs.twimg.com/profile_images/1243623122089041920/gVZIvphd_400x400.jpg" : "https://avatars.githubusercontent.com/u/18018524?s=280&v=4"))
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text(trackingService)
                        }
                    }
                }
            }
        }
        .navigationTitle("Tracking Service")
    }
}
