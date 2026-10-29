//
//  StitchesView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 10/28/26.
//
import SwiftUI

struct StitchesView: View {
    let viewModel: HomeListViewModel
    @EnvironmentObject private var router: NavigationRouter

    var body: some View {
        Group {
            if viewModel.stitchVideos.isEmpty {
                ContentUnavailableView {
                    Label("No Stitches Yet", systemImage: "film.stack")
                } description: {
                    Text("Combine your days into one video.")
                } actions: {
                    Button("New Stitch", systemImage: "plus") {
                        router.newStitch()
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(viewModel.videos.isEmpty)
                }
            } else {
                list
            }
        }
        .navigationTitle("Stitches")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HomeMoreMenu(viewModel: viewModel)
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button("New Stitch", systemImage: "plus") {
                    router.newStitch()
                }
                .disabled(viewModel.videos.isEmpty)
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.stitchVideos) { stitch in
                    Button {
                        router.push(.stitchDetail(stitch.id))
                    } label: {
                        StitchCard(stitch: stitch)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        VideoContextMenu(video: stitch, viewModel: viewModel)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}

private struct StitchCard: View {
    let stitch: StitchedVideoEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VideoThumbnail(video: stitch, cornerRadius: 10)
                .frame(width: 84)
            VStack(alignment: .leading, spacing: 4) {
                Text(stitch.displayTitle ?? stitch.listDisplayText)
                    .font(.headline)
                if stitch.displayTitle != nil {
                    Text(stitch.listDisplayText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let journalPreview = stitch.journalPreview {
                    Text(journalPreview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .frame(maxHeight: .infinity)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }
}
