//
//  MediaInfoView.swift
//  Sora
//
//  Created by Francesco on 05/01/25.
//

import SwiftUI
import Kingfisher

struct MediaInfoView: View {
    let title: String
    let imageUrl: String
    let href: String
    let module: ScrapingModule
    
    var body: some View {
        VStack {
            KFImage(URL(string: imageUrl))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .padding()
            
            Text(title)
                .font(.largeTitle)
                .padding()
            
            Button(action: {
                if let url = URL(string: href) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Open Link")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .padding()
            
            Spacer()
        }
        .navigationTitle("Media Info")
        .navigationBarTitleDisplayMode(.inline)
    }
}
