//
//  HomeChrome.swift
//  1SecJournal
//
//  Created by Mike Griffin on 10/28/26.
//
import SwiftUI

extension View {
    /// Dialogs, sheets and overlays shared by the Days and Stitches tabs. Attached once,
    /// above the tabs, so the hidden tab doesn't present them a second time.
    func homeChrome(_ viewModel: HomeListViewModel) -> some View {
        modifier(HomeChrome(viewModel: viewModel))
    }
}

private struct HomeChrome: ViewModifier {
    @Bindable var viewModel: HomeListViewModel

    func body(content: Content) -> some View {
        content
            .sheet(item: $viewModel.selectedShareURL) { video in
                ShareSheet(activityItems: [video.url])
            }
            .sheet(item: $viewModel.backupShareURL) { backup in
                ShareSheet(activityItems: [backup.url])
            }
            .confirmationDialog(
                viewModel.pendingDeletion?.video is StitchedVideoEntry ? "Delete this stitch?" : "Delete this video?",
                isPresented: Binding(
                    get: { viewModel.pendingDeletion != nil },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.pendingDeletion = nil
                        }
                    }
                ),
                titleVisibility: .visible,
                presenting: viewModel.pendingDeletion
            ) { deletion in
                Button("Delete", role: .destructive) {
                    viewModel.confirmDelete(deletion)
                }
            } message: { deletion in
                Text(deletion.message)
            }
            .overlay {
                if viewModel.isPreparingBackup {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Preparing backup…")
                                .font(.headline)
                        }
                        .padding(24)
                        .glassEffect(in: .rect(cornerRadius: 20))
                    }
                }
            }
            .overlay(alignment: .top) {
                if let errorMessage = viewModel.errorMessage {
                    ToastView(message: errorMessage)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.default, value: viewModel.errorMessage)
            .task(id: viewModel.errorMessage) {
                guard viewModel.errorMessage != nil,
                      (try? await Task.sleep(for: .seconds(4))) != nil else { return }
                viewModel.errorMessage = nil
            }
    }
}

/// Backup and recovery, in the navigation bar of both tabs
struct HomeMoreMenu: View {
    let viewModel: HomeListViewModel
    @EnvironmentObject private var router: NavigationRouter

    var body: some View {
        Menu {
            Button("Export Backup", systemImage: "externaldrive") {
                viewModel.exportBackup()
            }
            .disabled(viewModel.isPreparingBackup)
            Button("Recover Videos", systemImage: "arrow.uturn.backward.circle") {
                router.push(.recoverVideos)
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel("More")
    }
}

/// Long-press actions for a video or stitch
struct VideoContextMenu: View {
    let video: VideoEntry
    let viewModel: HomeListViewModel
    @EnvironmentObject private var router: NavigationRouter

    var body: some View {
        if video is DailyVideoEntry {
            Button("Stitch from This Day", systemImage: "film.stack") {
                router.newStitch(StitchRequest(preselectedIDs: [video.id]))
            }
        }
        Button("Share", systemImage: "square.and.arrow.up") {
            viewModel.setShareURL(video)
        }
        Button("Delete", systemImage: "trash", role: .destructive) {
            viewModel.requestDelete(video)
        }
    }
}

/// A video's thumbnail at 9:16, filling the width it's given
struct VideoThumbnail: View {
    let video: VideoEntry
    var cornerRadius: CGFloat = 12

    var body: some View {
        Color.gray.opacity(0.2)
            .aspectRatio(9 / 16, contentMode: .fit)
            .overlay {
                if let image = video.thumbnailImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
