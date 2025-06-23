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
    case recordAndStitch

    var id: String {
        switch self {
        case .recordOnly: return "record"
        case .recordAndStitch: return "stitch"
        }
    }
}

struct SelectedIdentifiableURL: Identifiable, CustomStringConvertible {
    let id = UUID()
    let url: URL

    var description: String { "" } // prevents UUID or file path from flashing on sheet
}

struct ComposedStitchVideo: Identifiable {
    let id = UUID()
    let url: URL
    let dailyVideos: [DailyVideoEntry]
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
    
    // Create a stitch of videos
    //var stichVideoUrl: SelectedIdentifiableURL?
    var selectedComposedStitchVideo: ComposedStitchVideo?
    
    var modelContext: ModelContext
    
    init(_ modelContext: ModelContext) {
        self.modelContext = modelContext
        handleFetchAndGroupVideos()
        fetchStitchVideos()
    }
    
    func handleEnterForeground() {
        handleFetchAndGroupVideos()
    }
    
    func handleFetchAndGroupVideos() {
        fetchDailyVideos()
        groupVideos()
    }
    
    private func fetchDailyVideos() {
        do {
            let descriptor = FetchDescriptor<DailyVideoEntry>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            self.videos = try modelContext.fetch(descriptor)
        } catch {
            reportIssue(error)
        }
    }
    
    private func fetchStitchVideos() {
        do {
            let descriptor = FetchDescriptor<StitchedVideoEntry>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            self.stitchVideos = try modelContext.fetch(descriptor)
            print("Fetched: \(stitchVideos.count) stitch videos")
        } catch {
            print("Failed to fetch stitch videos: \(error)")
        }
    }
    
    private func groupVideos() {
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

    
    private func getThumbnail(from videoURL: URL) async -> UIImage? {
            let asset = AVURLAsset(url: videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true

            let time = CMTime(seconds: 1, preferredTimescale: 600) // 1 second into video
            do {
                // It's possible I'm not throwing the error properly, but I think it should be
                return try await withCheckedThrowingContinuation { continuation in
                    imageGenerator.generateCGImageAsynchronously(for: time) { cgImage,_,_  in         if let cgImage = cgImage {
                            continuation.resume(returning: UIImage(cgImage: cgImage))
                        }
                    }
                }
            } catch {
                reportIssue("Failed to generate thumbnail: \(error)")
                return nil
            }
        
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
    
    // This should be refactored to two different functions. But for now this works
    func saveVideo(url: URL, dailyVideos: [DailyVideoEntry]?) async {
        guard let (fileName, thumbnailFileName) = await VideoFileManager.generateVideoFileURLs(url: url) else {
            return
        }

            if let dailyVideos = dailyVideos {
                let stitchedVideo = StitchedVideoEntry(filename: fileName, thumbnailFilename: thumbnailFileName, composingVideos: dailyVideos)
                modelContext.insert(stitchedVideo)
                AppLogger.log("Stitch Video inserted in modelContext \(stitchedVideo.id)")

            } else {
                let newVideo = DailyVideoEntry(filename: fileName, thumbnailFilename: thumbnailFileName)
                videos.append(newVideo)
                modelContext.insert(newVideo)
                groupVideos()
            }
                

        

    }
    
    func saveStitchSelection() async {
        guard let stitchSelection = selectedComposedStitchVideo else {
            return
        }
        await saveVideo(url: stitchSelection.url, dailyVideos: stitchSelection.dailyVideos)
    }
    
    // MARK: Combine Stitch Videos to create a new one
    func combineVideos(_ videos: [DailyVideoEntry]) async {
        let videos = videos.sorted(by: { $0.date < $1.date })
        if let outputURL = await AVManager.combineVideos(videos: videos) {
            selectedComposedStitchVideo = ComposedStitchVideo(url: outputURL, dailyVideos: videos)
        }
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
        return NewVideoPromptViewModel(videos: videos){ [weak self] in
            self?.createPromptType = nil
        } onSave: { [weak self] url in
            Task {
               await self?.saveVideo(url: url, dailyVideos: nil)
            }
        } onSelectedStitchVideos: { [weak self] selectedStitchVideos in
            // create a new video that combines the videos
            // set this url into a new value
            Task.detached(priority: .userInitiated) {
                await self?.combineVideos(selectedStitchVideos)
            }
        }
        
    }
}
