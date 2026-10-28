//
//  CreateStitchViewModel.swift
//  1SecJournal
//
//  Created by Mike Griffin on 6/7/25.
//
import SwiftUI
import SwiftData

enum StitchTimeframe: String, CaseIterable {
    case custom
    case month
    case year
}

/// The videos from one month or year
struct PeriodGroup: Identifiable {
    let period: VideoPeriod
    /// Oldest first
    let videos: [DailyVideoEntry]

    var id: VideoPeriod { period }
}

enum PeriodSelection {
    case none
    case partial
    case all
}

@MainActor
@Observable
class CreateStitchViewModel {
    enum CreationState: Equatable {
        case selecting
        /// nil until the first progress update arrives
        case creating(progress: Double?)
        /// The stitched video, still in the temporary directory until it's saved
        case preview(URL)
    }

    // The selection carries across tabs, so a month picked here shows as checked videos in Custom
    var selectedTimeFrame: StitchTimeframe = .custom
    var videos: [DailyVideoEntry]
    let monthGroups: [PeriodGroup]
    let yearGroups: [PeriodGroup]
    var selectedIds: Set<UUID> = []
    var modelContext: ModelContext
    var creationState: CreationState = .selecting
    var isSaving = false
    /// Optional, entered on the preview before saving
    var title = ""
    /// Shown as a toast
    var errorMessage: String?
    /// The videos in the stitch being created, oldest first
    private(set) var stitchSources: [DailyVideoEntry] = []
    @ObservationIgnored private var creationTask: Task<Void, Never>?

    var isCreating: Bool {
        if case .creating = creationState { return true }
        return false
    }

    var previewURL: URL? {
        if case .preview(let url) = creationState { return url }
        return nil
    }
        
    init(videos: [DailyVideoEntry],
         preselectedVideoId: UUID? = nil,
         modelContext: ModelContext) {
        self.videos = videos
        self.modelContext = modelContext
        monthGroups = VideoPeriod.group(videos, by: .month, date: \.date)
            .map { PeriodGroup(period: $0.period, videos: $0.items) }
        yearGroups = VideoPeriod.group(videos, by: .year, date: \.date)
            .map { PeriodGroup(period: $0.period, videos: $0.items) }

        if let preselectedVideoId {
            selectedIds.insert(preselectedVideoId)
        }
    }
    
    func createStitch() {
        guard creationState == .selecting else { return }
        let sources = videos
            .filter { selectedIds.contains($0.id) }
            .sorted { $0.date < $1.date }
        guard !sources.isEmpty else { return }

        stitchSources = sources
        // SwiftData models stay on the main actor, so the stitcher gets plain values
        let clips = sources.map { StitchClip(url: $0.fileURL, date: $0.date) }
        creationState = .creating(progress: nil)

        creationTask = Task { [weak self] in
            do {
                let url = try await AVManager.combineVideos(clips: clips) { fraction in
                    Task { @MainActor in self?.updateProgress(fraction) }
                }
                guard let self, !Task.isCancelled else {
                    try? FileManager.default.removeItem(at: url)
                    return
                }
                AppLogger.log("Combined videos to create stitched video with outputURL \(url)")
                self.creationState = .preview(url)
            } catch {
                // cancelStitch has already reset the state
                guard !Task.isCancelled, let self else { return }
                AppLogger.log("Failed to combine videos: \(error)", level: .error)
                self.creationState = .selecting
                self.errorMessage = (error as? StitchError)?.errorDescription
                    ?? "Couldn't create the stitch. Please try again."
            }
        }
    }

    private func updateProgress(_ fraction: Double) {
        // Updates hop to the main actor separately, so ignore any that arrive late or out of order
        guard case .creating(let current) = creationState, fraction > (current ?? 0) else { return }
        creationState = .creating(progress: min(fraction, 1))
    }

    func cancelStitch() {
        creationTask?.cancel()
        creationTask = nil
        creationState = .selecting
    }

    func discardStitch() {
        if let previewURL {
            try? FileManager.default.removeItem(at: previewURL)
        }
        creationState = .selecting
    }

    /// Copies the stitch into the app group and inserts it. Returns whether it saved.
    func saveStitch() async -> Bool {
        guard let previewURL, !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }

        guard let (fileName, thumbnailFileName) = await VideoFileManager.generateVideoFileURLs(url: previewURL) else {
            errorMessage = "Couldn't save the stitch. Please try again."
            return false
        }
        let stitchedVideo = StitchedVideoEntry(filename: fileName,
                                               thumbnailFilename: thumbnailFileName,
                                               composingVideos: stitchSources)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            stitchedVideo.title = trimmedTitle
        }
        modelContext.insert(stitchedVideo)
        do {
            try modelContext.save()
        } catch {
            AppLogger.log("Failed to save stitch \(stitchedVideo.id): \(error)", level: .error)
        }
        AppLogger.log("Stitch Video inserted in modelContext \(stitchedVideo.id)")
        try? FileManager.default.removeItem(at: previewURL)
        return true
    }

    /// Stops any work in progress and removes an unsaved stitch
    func handleDisappear() {
        if isCreating {
            cancelStitch()
        } else if !isSaving {
            discardStitch()
        }
    }
    
    func selection(of group: PeriodGroup) -> PeriodSelection {
        let selectedCount = group.videos.count { selectedIds.contains($0.id) }
        if selectedCount == 0 { return .none }
        return selectedCount == group.videos.count ? .all : .partial
    }

    /// Selects every video in the period, or clears them if they're all selected already
    func togglePeriod(_ group: PeriodGroup) {
        let ids = group.videos.map(\.id)
        if selection(of: group) == .all {
            selectedIds.subtract(ids)
        } else {
            selectedIds.formUnion(ids)
        }
    }

    func selectVideo(_ video: DailyVideoEntry) {
        if selectedIds.contains(video.id) {
            selectedIds.remove(video.id)
        } else {
            selectedIds.insert(video.id)
        }
    }
}
