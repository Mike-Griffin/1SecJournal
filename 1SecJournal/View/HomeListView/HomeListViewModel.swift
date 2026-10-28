//
//  HomeListViewModel.swift
//  1SecJournal
//
//  Created by Mike Griffin on 6/1/25.
//

import SwiftUI
import SwiftData
import AVFoundation
import IssueReporting

let kAppGroup = "group.com.comedichoney.1SecJournal"

struct VideoSection: Hashable, Equatable, Comparable {
    enum GroupType: Hashable {
        case today
        case month(String)
        case year(String)
    }
    
    let type: GroupType
    let sortDate: Date
    
    var title: String {
        switch type {
        case .today:
            return "Today"
        case .month(let month):
            return month
        case .year(let year):
            return year
        }
    }
    
    static func < (lhs: VideoSection, rhs: VideoSection) -> Bool {
        return lhs.sortDate > rhs.sortDate // reverse chronological
    }
}

enum CreatePromptType: Identifiable {
    case recordOnly

    var id: String {
        switch self {
        case .recordOnly: return "record"
        }
    }
}

struct SelectedIdentifiableURL: Identifiable, CustomStringConvertible {
    let id = UUID()
    let url: URL

    var description: String { "" } // prevents UUID or file path from flashing on sheet
}

struct PendingDeletion: Identifiable {
    let video: VideoEntry
    /// How many stitches a daily video is part of
    let stitchCount: Int
    
    var id: UUID { video.id }
    
    var message: String {
        if video is StitchedVideoEntry {
            return "This removes the stitch from your journal and your phone. The daily videos in it aren't affected."
        }
        switch stitchCount {
        case 0: return "This removes the video from your journal and your phone. It can't be undone."
        case 1: return "It's used in 1 stitch, which will keep playing but won't list this day. This can't be undone."
        default: return "It's used in \(stitchCount) stitches, which will keep playing but won't list this day. This can't be undone."
        }
    }
}

enum VideoListDisplayType: String, CaseIterable {
    case daily
    case stitch
}

@MainActor
@Observable class HomeListViewModel {
    var videoListDisplayType: VideoListDisplayType = .daily
    
    // Daily Video Display
    var videos: [DailyVideoEntry] = []
    var sectionedVideos: [(section: VideoSection, videos: [DailyVideoEntry])] = []
    
    // Stitch Video Display
    var stitchVideos: [StitchedVideoEntry] = []
    
    // Share Sheet
    var selectedShareURL: SelectedIdentifiableURL?
    
    // Delete
    /// Waiting on the confirmation dialog
    var pendingDeletion: PendingDeletion?
    
    // Backup
    var isPreparingBackup = false
    var backupShareURL: SelectedIdentifiableURL?
    /// Shown as a toast
    var errorMessage: String?
    
    // Prompt Management
    var createPromptType: CreatePromptType?
    var uploadTodayVideoCTATapped: Bool = false
    @ObservationIgnored private var lastGroupedDate = Date()
    
    var modelContext: ModelContext
    
    init(_ modelContext: ModelContext) {
        self.modelContext = modelContext
        handleFetchAndGroupVideos()
        fetchStitchVideos()
    }
    
    /// Only reassigns the lists when their contents changed, so a refresh during
    /// a navigation transition doesn't rebuild the list unnecessarily
    func refresh() {
        let dailyChanged = fetchDailyVideos()
        // Regroup on a new day too, so "Today" stays correct if the app stays open overnight
        if dailyChanged || !Calendar.current.isDate(lastGroupedDate, inSameDayAs: Date()) {
            groupVideos()
        }
        fetchStitchVideos()
    }
    
    func handleFetchAndGroupVideos() {
        fetchDailyVideos()
        groupVideos()
    }
    
    /// Returns whether the fetched videos differ from the current ones
    @discardableResult
    private func fetchDailyVideos() -> Bool {
        do {
            let descriptor = FetchDescriptor<DailyVideoEntry>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let fetched = try modelContext.fetch(descriptor)
            guard fetched.map(\.id) != videos.map(\.id) else { return false }
            self.videos = fetched
            return true
        } catch {
            reportIssue(error)
            return false
        }
    }
    
    private func fetchStitchVideos() {
        do {
            let descriptor = FetchDescriptor<StitchedVideoEntry>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let fetched = try modelContext.fetch(descriptor)
            guard fetched.map(\.id) != stitchVideos.map(\.id) else { return }
            self.stitchVideos = fetched
            AppLogger.log("Fetched: \(stitchVideos.count) stitch videos")
        } catch {
            AppLogger.log("Failed to fetch stitch videos: \(error)")
        }
    }
    
    private func groupVideos() {
        lastGroupedDate = Date()
        var groupedVideos: [VideoSection: [DailyVideoEntry]] = [:]

        let calendar = Calendar.current

        for video in videos {
            let section: VideoSection
            if calendar.isDateInToday(video.date) {
                section = VideoSection(type: .today, sortDate: calendar.startOfDay(for: video.date))
            } else if calendar.isDate(video.date, equalTo: Date(), toGranularity: .year) {
                // use the month as the display if it's this year
                let month = VideoPeriod(.month, containing: video.date)
                section = VideoSection(type: .month(month.monthName), sortDate: month.start)
            } else {
                let year = VideoPeriod(.year, containing: video.date)
                section = VideoSection(type: .year(year.title), sortDate: year.start)
            }
            groupedVideos[section, default: []].append(video)
        }
        
        sectionedVideos = groupedVideos
            .map { ($0.key, $0.value.sorted(by: { $0.date > $1.date })) }
            .sorted { $0.0 < $1.0 }
        
    }

    
    func setShareURL(_ video: VideoEntry) {
        let tempDirectory = FileManager.default.temporaryDirectory
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let targetURL = tempDirectory.appendingPathComponent("1SecVid_\(formatter.string(from: video.date)).mov")

        do {
            // Remove existing file if needed
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
            try FileManager.default.copyItem(at: video.fileURL, to: targetURL)
            selectedShareURL = SelectedIdentifiableURL(url: targetURL)
        } catch {
            reportIssue(error, "Failed to copy file for sharing:")
         }
    }
    
    func exportBackup() {
        guard !isPreparingBackup else { return }
        isPreparingBackup = true
        // Writes pending changes so the store on disk is current
        do {
            try modelContext.save()
        } catch {
            AppLogger.log("Failed to save before backup: \(error)", level: .error)
        }
        Task {
            defer { isPreparingBackup = false }
            do {
                let url = try await BackupExporter.makeBackup()
                AppLogger.log("Backup created at \(url)")
                backupShareURL = SelectedIdentifiableURL(url: url)
            } catch {
                AppLogger.log("Backup failed: \(error)", level: .error)
                errorMessage = "Couldn't create the backup. \(error.localizedDescription)"
            }
        }
    }
    
    /// Asks for confirmation first, since deleting also removes the video's files
    func requestDelete(_ video: VideoEntry) {
        var stitchCount = 0
        if let dailyVideo = video as? DailyVideoEntry {
            stitchCount = (try? VideoLibrary.stitches(containing: dailyVideo, in: modelContext).count) ?? 0
        }
        pendingDeletion = PendingDeletion(video: video, stitchCount: stitchCount)
    }
    
    func confirmDelete(_ deletion: PendingDeletion) {
        pendingDeletion = nil
        do {
            try VideoLibrary.delete(deletion.video, in: modelContext)
        } catch {
            AppLogger.log("Failed to delete \(deletion.video.id): \(error)", level: .error)
            errorMessage = "Couldn't delete the video. Please try again."
        }
        refresh()
    }
    
    func saveVideo(url: URL) async {
        guard let (fileName, thumbnailFileName) = await VideoFileManager.generateVideoFileURLs(url: url) else {
            return
        }
        let newVideo = DailyVideoEntry(filename: fileName, thumbnailFilename: thumbnailFileName)
        videos.append(newVideo)
        modelContext.insert(newVideo)
        groupVideos()
    }

    
    // Prompt Management
    func shouldShowTodayPrompt() -> Bool {
        if uploadTodayVideoCTATapped {
            return false
        }
        let calendar = Calendar.current
        guard let firstSection = sectionedVideos.first else { return false }
        return firstSection.section.sortDate != calendar.startOfDay(for: Date())
    }
    

    
    func makeMakePromptViewModel() -> NewVideoPromptViewModel {
        return NewVideoPromptViewModel { [weak self] in
            self?.createPromptType = nil
        } onSave: { [weak self] url in
            Task {
               await self?.saveVideo(url: url)
            }
        }
    }
}
