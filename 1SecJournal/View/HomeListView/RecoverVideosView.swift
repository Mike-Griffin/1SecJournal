//
//  RecoverVideosView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 10/27/26.
//
import SwiftUI
import SwiftData
import AVFoundation

@MainActor
@Observable final class RecoverVideosViewModel {
    struct Item: Identifiable {
        let files: VideoLibrary.UnlinkedVideo
        /// When the video was recorded, else when its file was created
        let date: Date?
        let duration: Double?

        var id: String { files.id }
        var hasVideo: Bool { files.videoFilename != nil }
    }

    var items: [Item] = []
    var isLoading = true
    var previewItem: Item?
    var isConfirmingDeleteAll = false
    /// Shown as a toast
    var errorMessage: String?

    private let modelContext: ModelContext

    init(_ modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func load() async {
        defer { isLoading = false }
        do {
            var loaded: [Item] = []
            for files in try VideoLibrary.unlinkedFiles(in: modelContext) {
                loaded.append(await Self.makeItem(files))
            }
            // Newest first, thumbnails without a video last
            items = loaded.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        } catch {
            AppLogger.log("Failed to find unlinked files: \(error)", level: .error)
            errorMessage = "Couldn't look for videos to recover."
        }
    }

    func restore(_ item: Item, as kind: VideoLibrary.RestoreKind) async {
        previewItem = nil
        do {
            try await VideoLibrary.restore(item.files, as: kind, date: item.date ?? Date(), in: modelContext)
            items.removeAll { $0.id == item.id }
        } catch {
            AppLogger.log("Failed to restore \(item.id): \(error)", level: .error)
            errorMessage = "Couldn't add the video. Please try again."
        }
    }

    func delete(_ item: Item) {
        previewItem = nil
        VideoLibrary.removeFiles(of: item.files)
        items.removeAll { $0.id == item.id }
    }

    func deleteAll() {
        for item in items {
            VideoLibrary.removeFiles(of: item.files)
        }
        items = []
    }

    private static func makeItem(_ files: VideoLibrary.UnlinkedVideo) async -> Item {
        guard let videoFilename = files.videoFilename,
              let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup) else {
            return Item(files: files, date: nil, duration: nil)
        }
        let url = containerURL.appending(path: videoFilename)
        let asset = AVURLAsset(url: url)
        var date = try? await asset.load(.creationDate)?.load(.dateValue)
        if date == nil {
            date = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
        }
        let duration = try? await asset.load(.duration).seconds
        return Item(files: files, date: date, duration: duration)
    }
}

/// Lists video files that are on the phone but not in the journal, so they can be
/// added back or deleted
struct RecoverVideosView: View {
    @State private var viewModel: RecoverVideosViewModel

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: RecoverVideosViewModel(modelContext))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.items.isEmpty {
                ContentUnavailableView("Nothing to Recover",
                                       systemImage: "checkmark.circle",
                                       description: Text("Every video on your phone is in your journal."))
            } else {
                list
            }
        }
        .navigationTitle("Recover Videos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.items.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete All", role: .destructive) {
                        viewModel.isConfirmingDeleteAll = true
                    }
                }
            }
        }
        .confirmationDialog("Delete all \(viewModel.items.count) videos?",
                            isPresented: $viewModel.isConfirmingDeleteAll,
                            titleVisibility: .visible) {
            Button("Delete All", role: .destructive) {
                viewModel.deleteAll()
            }
        } message: {
            Text("They'll be removed from your phone. This can't be undone.")
        }
        .sheet(item: $viewModel.previewItem) { item in
            RecoverVideoPreview(item: item, viewModel: viewModel)
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
        .task {
            await viewModel.load()
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(viewModel.items) { item in
                    Button {
                        if item.hasVideo {
                            viewModel.previewItem = item
                        }
                    } label: {
                        RecoverVideoRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            viewModel.delete(item)
                        }
                    }
                }
            } footer: {
                Text("These videos are on your phone but not in your journal, usually because a save didn't finish. Tap one to watch it, then add it back or delete it.")
            }
        }
    }
}

private struct RecoverVideoRow: View {
    let item: RecoverVideosViewModel.Item

    var body: some View {
        HStack(spacing: 16) {
            Color.gray.opacity(0.3)
                .frame(width: 48, height: 48 * 16 / 9)
                .overlay {
                    if let image = thumbnail {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.date?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown date")
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }

    private var detail: String {
        guard item.hasVideo else { return "Thumbnail only, no video" }
        guard let duration = item.duration else { return "Video" }
        return duration.formatted(.number.precision(.fractionLength(1))) + " sec video"
    }

    private var thumbnail: UIImage? {
        guard let filename = item.files.thumbnailFilename,
              let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup) else {
            return nil
        }
        return UIImage(contentsOfFile: containerURL.appending(path: filename).path(percentEncoded: false))
    }
}

private struct RecoverVideoPreview: View {
    let item: RecoverVideosViewModel.Item
    let viewModel: RecoverVideosViewModel

    var body: some View {
        VStack(spacing: 12) {
            if let url {
                VideoPlaybackView(url: url)
            }
            Text(item.date?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown date")
                .font(.headline)
            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.restore(item, as: .daily) }
                } label: {
                    Text("Add as Daily Video").frame(maxWidth: .infinity)
                }
                Button {
                    Task { await viewModel.restore(item, as: .stitch) }
                } label: {
                    Text("Add as Stitch").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            // The app's accent color is white
            .tint(.blue)
            Button("Delete", role: .destructive) {
                viewModel.delete(item)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .presentationDragIndicator(.visible)
    }

    private var url: URL? {
        guard let filename = item.files.videoFilename else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup)?
            .appending(path: filename)
    }
}
