//
//  MarqueeText.swift
//  Sulfur
//
//  Created by Francesco on 25/06/25.
//

import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    
    @State private var animate = false
    @State private var textSize: CGSize = .zero
    @State private var containerWidth: CGFloat = 0
    
    init(_ text: String, font: Font = .body, color: Color = .white) {
        self.text = text
        self.font = font
        self.color = color
    }
    
    var body: some View {
        GeometryReader { geometry in
            if textSize.width > geometry.size.width {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(text)
                        .font(font)
                        .foregroundColor(color)
                        .lineLimit(1)
                        .offset(x: animate ? -textSize.width - 20 : geometry.size.width)
                        .onAppear {
                            containerWidth = geometry.size.width
                            withAnimation(Animation.linear(duration: Double(textSize.width + containerWidth) / 30.0)
                                .repeatForever(autoreverses: false)) {
                                    animate = true
                                }
                        }
                }
            } else {
                Text(text)
                    .font(font)
                    .foregroundColor(color)
                    .lineLimit(1)
            }
        }
        .background(
            Text(text)
                .font(font)
                .lineLimit(1)
                .hidden()
                .background(GeometryReader { geometry in
                    Color.clear.onAppear {
                        textSize = geometry.size
                    }
                })
        )
    }
}
