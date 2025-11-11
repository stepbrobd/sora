//
//  StretchyHeader.swift
//  Sora
//
//  Created by Francesco on 07/08/25.
//

import SwiftUI
import Nuke
import NukeUI

struct StretchyHeaderView: View {
    let backdropURL: String?
    let headerHeight: CGFloat
    let minHeaderHeight: CGFloat
    
    @State private var localAmbientColor: Color = Color.black
    @State private var backdropImage: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .global)
            let deltaY = frame.minY
            let height = headerHeight + max(0, deltaY)
            let offset = min(0, -deltaY)
            
            ZStack(alignment: .bottom) {
                Color.clear
                    .overlay(
                        LazyImage(url: URL(string: backdropURL ?? "")) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                        }
                        .onCompletion { result in
                            if case .success(let response) = result {
                                let uiImage = response.image
                                backdropImage = uiImage
                                let extractedColor = Color.ambientColor(from: uiImage)
                                localAmbientColor = extractedColor
                            }
                        },
                        alignment: .center
                    )
                    .clipped()
                    .frame(height: height)
                    .offset(y: offset)
                
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: localAmbientColor.opacity(0.0), location: 0.0),
                        .init(color: localAmbientColor.opacity(0.1), location: 0.2),
                        .init(color: localAmbientColor.opacity(0.3), location: 0.7),
                        .init(color: localAmbientColor.opacity(0.6), location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 0))
            }
        }
        .frame(height: headerHeight)
        .onAppear {
            if let backdropURL = backdropURL, let url = URL(string: backdropURL) {
                Task {
                    let request = ImageRequest(url: url)
                    if let response = try? await ImagePipeline.shared.image(for: request) {
                        await MainActor.run {
                            backdropImage = response
                            let extractedColor = Color.ambientColor(from: response)
                            localAmbientColor = extractedColor
                        }
                    }
                }
            }
        }
    }
}
