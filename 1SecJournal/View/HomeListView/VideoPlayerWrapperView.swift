//
//  VideoPlayerView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/30/25.
//

import SwiftUI
import AVKit

struct VideoPlayerWrapperView: View {
    let video: VideoEntry
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            let player = AVPlayer(url: video.fileURL)

            VideoPlayer(player: player)
                .navigationTitle("Playback")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear() {
                    // Always play from the beginning
                    player.seek(to: .zero)
                    player.play()
                }
                .onDisappear {
                    player.pause()
                }
            Text(video.date.videoFormattedDisplay)
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundColor(.white)
                .font(.caption)
                .padding()
        }
    }
}

//#Preview {
//    VideoPlayerView()
//}
