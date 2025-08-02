//
//  VideoPlayerWithOverlayView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 7/30/25.
//

import SwiftUI
import AVKit


struct  VideoPlayerWithOverlayView: View {
    @Binding var videoURL: URL?
    var body: some View {
        ZStack {
            if let url = videoURL {
                
                VideoPlayer(player: AVPlayer(url: url))
                // This was used in the original code to make it a small video view
//                    .aspectRatio(9/16, contentMode: .fill)
//                    .frame(height: 300)
//                    .clipped()
//                    .cornerRadius(10)
                HStack {
                    Spacer()
                    VStack(alignment: .trailing) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.black.opacity(0.6), Color.black.opacity(0.3)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 36, height: 36)
                                .blur(radius: 0)
                            
                            Button {
                                videoURL = nil
                            } label: {
                                Image(systemName: "trash.circle")
                                    .resizable()
                                    .frame(width: 36, height: 36)
                                    .foregroundStyle(.white)
                                    .padding()
                            }
                        }
                        Spacer()
                    }
                }
            } else {
                Text("VideoError")
            }
            
        }}
}
