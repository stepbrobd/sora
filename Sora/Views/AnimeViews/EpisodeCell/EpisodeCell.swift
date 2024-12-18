//
//  EpisodeCell.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI
import Kingfisher

struct EpisodeCell: View {
    let episode: String
    let episodeID: Int
    let imageUrl: String
    let progress: Double
    
    var body: some View {
        HStack {
            KFImage(URL(string: "https://cdn.discordapp.com/attachments/1218851049625092138/1318941731349332029/IMG_5081.png?ex=676427b5&is=6762d635&hm=923252d3448fda337f52c964f1428538095cbd018e36a6cfb21d01918e071c9d&"))
                .resizable()
                .aspectRatio(16/9, contentMode: .fill)
                .frame(width: 100, height: 56)
                .cornerRadius(8)
            
            VStack(alignment: .leading) {
                Text("Episode \(episodeID + 1)")
                    .font(.headline)
            }
            
            Spacer()
            
            CircularProgressBar(progress: progress)
                .frame(width: 40, height: 40)
        }
    }
}
