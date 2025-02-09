//
//  SkeletonCell.swift
//  Sora
//
//  Created by Francesco on 09/02/25.
//

import SwiftUI

struct HomeSkeletonCell: View {
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 130, height: 195)
                .cornerRadius(10)
                .shimmering()
            
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 130, height: 20)
                .padding(.top, 4)
                .shimmering()
        }
    }
}

struct SearchSkeletonCell: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 150, height: 225)
                .shimmering()
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 150, height: 20)
                .shimmering()
        }
    }
}
