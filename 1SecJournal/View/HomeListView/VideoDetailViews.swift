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
            VideoDetailLayout(video: video, journalPlaceholder: "Write about this day…") {
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
            } related: {
                if !stitches.isEmpty {
                    ThumbnailStrip(title: stitches.count == 1 ? "In 1 stitch" : "In \(stitches.count) stitches",
                                   videos: stitches) { stitch in
                        router.push(.stitchDetail(stitch.id))
                    }
                }
            }
            .navigationTitle(video.displayTitle ?? video.date.videoFormattedDisplay)
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
            VideoDetailLayout(video: stitch, journalPlaceholder: "Write about these days…") {
                VideoPlaybackView(url: stitch.fileURL)
            } related: {
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
            .navigationTitle(stitch.displayTitle ?? stitch.listDisplayText)
        } else {
            ContentUnavailableView("Stitch not found", systemImage: "video.slash")
        }
    }
}

/// The player, then the title and journal fields, then related videos. Scrolls so the
/// fields stay reachable with the keyboard up.
struct VideoDetailLayout<Player: View, Related: View>: View {
    @Environment(\.modelContext) private var modelContext
    let video: VideoEntry
    let journalPlaceholder: String
    @ViewBuilder let player: () -> Player
    @ViewBuilder let related: () -> Related

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                player()
                    .containerRelativeFrame(.vertical) { height, _ in height * 0.6 }
                JournalFields(video: video, journalPlaceholder: journalPlaceholder)
                related()
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            // Autosave would get there too; this keeps the edit if the app is closed right after
            do {
                try modelContext.save()
            } catch {
                AppLogger.log("Failed to save edits to \(video.id): \(error)", level: .error)
            }
        }
    }
}

/// Title and journal text, saved as they're typed
struct JournalFields: View {
    let video: VideoEntry
    let journalPlaceholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Add a title", text: binding(\.title), axis: .vertical)
                .font(.title3.weight(.semibold))
                // Lines up with the text inside the TextEditor below
                .padding(.horizontal, 5)
            ZStack(alignment: .topLeading) {
                // Sizes the editor to its text, since a TextEditor in a scroll view has no height of its own
                Text((video.journalText ?? "") + " ")
                    .padding(.vertical, 8)
                    .padding(.horizontal, 5)
                    .opacity(0)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                TextEditor(text: binding(\.journalText))
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(true)
                if (video.journalText ?? "").isEmpty {
                    Text(journalPlaceholder)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 5)
                        .allowsHitTesting(false)
                }
            }
            .font(.body)
        }
        .padding()
    }

    /// Stores empty text as nil and stamps updatedAt when the text changes
    private func binding(_ keyPath: ReferenceWritableKeyPath<VideoEntry, String?>) -> Binding<String> {
        Binding(
            get: { video[keyPath: keyPath] ?? "" },
            set: { newValue in
                let stored = newValue.isEmpty ? nil : newValue
                guard stored != video[keyPath: keyPath] else { return }
                video[keyPath: keyPath] = stored
                video.updatedAt = Date()
            }
        )
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
