//
//  VideoDetailViews.swift
//  1SecJournal
//
//  Created by Mike Griffin on 10/27/26.
//
import SwiftUI
import SwiftData
import AVKit

/// Plays from the start each time the screen appears. The player is kept in state
/// so redrawing the screen doesn't restart playback.
struct VideoPlaybackView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .task(id: url) {
                let newPlayer = AVPlayer(url: url)
                player = newPlayer
                newPlayer.play()
            }
            .onAppear {
                // Coming back from another screen; the first appearance is handled by the task
                player?.seek(to: .zero)
                player?.play()
            }
            .onDisappear {
                player?.pause()
            }
    }
}

struct DailyVideoDetailView: View {
    @EnvironmentObject private var router: NavigationRouter
    @Query private var matches: [DailyVideoEntry]
    @Query(sort: \StitchedVideoEntry.date, order: .reverse) private var allStitches: [StitchedVideoEntry]

    init(videoID: UUID) {
        _matches = Query(filter: #Predicate<DailyVideoEntry> { $0.id == videoID })
    }

    var body: some View {
        if let video = matches.first {
            let stitches = allStitches.filter { $0.sourceVideoIDs.contains(video.id) }
            VStack(spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    VideoPlaybackView(url: video.fileURL)
                    Text(video.date.videoFormattedDisplay)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundColor(.white)
                        .font(.caption)
                        .padding()
                }
                if !stitches.isEmpty {
                    ThumbnailStrip(title: stitches.count == 1 ? "In 1 stitch" : "In \(stitches.count) stitches",
                                   videos: stitches) { stitch in
                        router.push(.stitchDetail(stitch.id))
                    }
                }
            }
            .navigationTitle(video.date.videoFormattedDisplay)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Video not found", systemImage: "video.slash")
        }
    }
}

struct StitchDetailView: View {
    @EnvironmentObject private var router: NavigationRouter
    @Query private var matches: [StitchedVideoEntry]
    @Query private var allDailyVideos: [DailyVideoEntry]

    init(stitchID: UUID) {
        _matches = Query(filter: #Predicate<StitchedVideoEntry> { $0.id == stitchID })
    }

    var body: some View {
        if let stitch = matches.first {
            let dailyById = Dictionary(allDailyVideos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let sources = stitch.sourceVideoIDs.compactMap { dailyById[$0] }
            VStack(spacing: 0) {
                VideoPlaybackView(url: stitch.fileURL)
                if sources.isEmpty {
                    Text("The videos this stitch was made from aren't linked to it anymore.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    ThumbnailStrip(title: sources.count == 1 ? "Made from 1 video" : "Made from \(sources.count) videos",
                                   videos: sources) { source in
                        router.push(.videoDetail(source.id))
                    }
                }
            }
            .navigationTitle(stitch.listDisplayText)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Stitch not found", systemImage: "video.slash")
        }
    }
}

/// A titled, horizontally scrolling row of video thumbnails
struct ThumbnailStrip<Video: VideoEntry>: View {
    let title: String
    let videos: [Video]
    let onSelect: (Video) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(videos) { video in
                        Button {
                            onSelect(video)
                        } label: {
                            VStack(spacing: 4) {
                                Color.gray.opacity(0.3)
                                    .frame(width: 64, height: 64 * 16 / 9)
                                    .overlay {
                                        if let image = video.thumbnailImage {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                Text(caption(for: video))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(width: 76)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(video.listDisplayText)
                    }
                }
                .padding(.horizontal)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.vertical, 12)
        // Otherwise the strip takes half the screen from the player
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The day for a daily video, the range for a stitch
    private func caption(for video: Video) -> String {
        let format = Date.FormatStyle.dateTime.month(.abbreviated).day()
        if let stitch = video as? StitchedVideoEntry, let start = stitch.rangeStart, let end = stitch.rangeEnd {
            let startText = start.formatted(format)
            let endText = end.formatted(format)
            return startText == endText ? startText : "\(startText) – \(endText)"
        }
        return video.date.formatted(format)
    }
}
