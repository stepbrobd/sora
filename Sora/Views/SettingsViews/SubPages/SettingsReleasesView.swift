//
//  SettingsReleasesView.swift
//  Sora
//
//  Created by Francesco on 31/12/24.
//

import SwiftUI

struct SettingsReleasesView: View {
    @State private var releases: [GitHubReleases] = []
    
    var body: some View {
        List(releases, id: \.tagName) { release in
            VStack(alignment: .leading) {
                Text(release.tagName)
                    .font(.system(size: 17))
                    .bold()
                Text(release.body)
                    .font(.system(size: 14))
            }
            .contextMenu {
                Button(action: {
                    if let url = URL(string: release.htmlUrl) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("View on GitHub")
                    Image(systemName: "safari")
                }
            }
        }
        .navigationTitle("Releases")
        .onAppear {
            GitHubAPI.shared.fetchReleases { fetchedReleases in
                if let fetchedReleases = fetchedReleases {
                    self.releases = fetchedReleases
                }
            }
        }
    }
}
