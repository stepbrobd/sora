//
//  Shimmer.swift
//  Sora
//
//  Created by Francesco on 09/02/25.
//

import SwiftUI

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.4), Color.clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: self.phase * 350)
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    self.phase = 1
                }
            }
    }
}
