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
        let formatter = DateFormatter()

        for video in videos {
            let videoDate = video.date

            var section: VideoSection
            if calendar.isDateInToday(video.date) {
                section = VideoSection(type: .today, sortDate: calendar.startOfDay(for: video.date))
            } else if calendar.component(.year, from: video.date) == calendar.component(.year, from: Date()) {
                // use the month as the display if it's this year
                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: videoDate))!
                formatter.dateFormat = "MMMM"
                let monthName = formatter.monthSymbols[calendar.component(.month, from: videoDate) - 1]

                section = VideoSection(type: .month(monthName), sortDate: startOfMonth)
            } else {
                let startOfYear = calendar.date(from: DateComponents(year: calendar.component(.year, from: videoDate)))!

                formatter.dateFormat = "MMMM yy"
                section = VideoSection(type: .year(formatter.string(from: video.date)), sortDate: startOfYear)
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
    
    func deleteVideo(_ video: VideoEntry) {
        modelContext.delete(video)
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
