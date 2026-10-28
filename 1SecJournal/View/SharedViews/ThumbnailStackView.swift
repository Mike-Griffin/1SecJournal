//
//  ThumbnailStackView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 10/27/26.
//
import SwiftUI

/// Thumbnails drawn as a stack of cards, the first one on top
/// with the edges of up to two more fanned out behind it
struct ThumbnailStackView: View {
    let images: [UIImage?]
    var cornerRadius: CGFloat = 8

    private static let maxBackCards = 2

    var body: some View {
        let backCards = Array(images.dropFirst().prefix(Self.maxBackCards).enumerated())
        ZStack {
            // Drawn farthest first so each card sits on top of the one behind it
            ForEach(backCards.reversed(), id: \.offset) { index, image in
                let depth = Double(index + 1)
                card(image)
                    .brightness(-0.08 * depth)
                    .rotationEffect(.degrees(4 * depth), anchor: .bottom)
                    .offset(x: 5 * depth, y: -3 * depth)
            }
            card(images.first ?? nil)
        }
        // Room for the fanned cards so they stay inside the cell
        .padding(.top, 10)
        .padding(.trailing, 14)
        .accessibilityHidden(true)
    }

    private func card(_ image: UIImage?) -> some View {
        Color.gray.opacity(0.3)
            .aspectRatio(9/16, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.white.opacity(0.85), lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }
}

#Preview {
    ThumbnailStackView(images: [nil, nil, nil])
        .frame(width: 160)
        .padding()
}
