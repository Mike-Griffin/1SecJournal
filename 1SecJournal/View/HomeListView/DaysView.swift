//
//  DaysView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/16/25.
//
import SwiftUI

/// Every daily video, in a grid grouped by month (this year) or year (earlier)
struct DaysView: View {
    let viewModel: HomeListViewModel
    @EnvironmentObject private var router: NavigationRouter

    private let columns = [GridItem(.adaptive(minimum: 80), spacing: 6)]

    var body: some View {
        Group {
            if viewModel.videos.isEmpty {
                ContentUnavailableView {
                    Label("No Videos Yet", systemImage: "video")
                } description: {
                    Text("Record a second of your day to start your journal.")
                } actions: {
                    Button("Record Today", systemImage: "camera.fill") {
                        router.openRecorder()
                    }
                    .buttonStyle(.glassProminent)
                }
            } else {
                grid
            }
        }
        .navigationTitle("Days")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HomeMoreMenu(viewModel: viewModel)
            }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if viewModel.shouldShowTodayPrompt() {
                    RecordTodayCard {
                        router.openRecorder()
                    }
                }
                ForEach(viewModel.sectionedVideos, id: \.section) { section, videos in
                    VStack(alignment: .leading, spacing: 12) {
                        header(section, videos: videos)
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(videos) { video in
                                Button {
                                    router.push(.videoDetail(video.id))
                                } label: {
                                    DayTile(video: video)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    VideoContextMenu(video: video, viewModel: viewModel)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private func header(_ section: VideoSection, videos: [DailyVideoEntry]) -> some View {
        HStack {
            Text(section.title)
                .font(.title2.bold())
            Spacer()
            if let timeframe = section.stitchTimeframe {
                Button("Stitch", systemImage: "film.stack") {
                    router.newStitch(StitchRequest(preselectedIDs: Set(videos.map(\.id)), timeframe: timeframe))
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .accessibilityLabel("Stitch \(section.title)")
            }
        }
    }
}

private extension VideoSection {
    /// Which Create Stitch tab shows this section as one period. Today has none.
    var stitchTimeframe: StitchTimeframe? {
        switch type {
        case .today: return nil
        case .month: return .month
        case .year: return .year
        }
    }
}

private struct DayTile: View {
    let video: DailyVideoEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VideoThumbnail(video: video)
                .overlay(alignment: .bottomLeading) {
                    Text(video.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassEffect(in: .capsule)
                        .padding(6)
                }
            if let title = video.displayTitle {
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([video.date.videoFormattedDisplay, video.displayTitle].compactMap { $0 }.joined(separator: ", "))
    }
}

private struct RecordTodayCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.title2)
                    .frame(width: 52, height: 52)
                    .glassEffect(.regular.tint(.blue).interactive(), in: .circle)
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Record today")
                        .font(.headline)
                    Text("You haven't saved a second for today yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}
