//
//  HomeListViewModel.swift
//  1SecJournal
//
//  Created by Mike Griffin on 6/1/25.
//

import SwiftUI
import SwiftData
import AVFoundation

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
            print("Failed to fetch videos: \(error)")
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
                print("❌ Failed to generate thumbnail: \(error)")
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
            print("❌ Failed to copy file for sharing:", error)
         }
    }
    
    func deleteVideo(_ video: VideoEntry) {
        modelContext.delete(video)
    }
    
    func saveVideo(url: URL, dailyVideos: [DailyVideoEntry]?) async {
        
        let uuidString = UUID().uuidString
        
        let fileName = uuidString + ".mov"
        
        // Get the Documents directory
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup) else {
            print("invalid containerURL")
            return
        }
        let destinationURL = containerURL.appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path()) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.copyItem(at: url, to: destinationURL)
            print("Video saved to: \(destinationURL)")
            var thumbnailFileName = ""
            if let thumbnailImage = await getThumbnail(from: destinationURL) {
                thumbnailFileName = uuidString + "thumb.jpg"
                let thumbDestinationURL = containerURL.appendingPathComponent(thumbnailFileName)
                if FileManager.default.fileExists(atPath: thumbDestinationURL.path()) {
                    try FileManager.default.removeItem(at: thumbDestinationURL)
                }
                
                if let data = thumbnailImage.jpegData(compressionQuality: 0.8) {
                    do {
                        try data.write(to: thumbDestinationURL)
                    }
                }

            }
            if let dailyVideos = dailyVideos {
                let stitchedVideo = StitchedVideoEntry(filename: fileName, thumbnailFilename: thumbnailFileName, composingVideos: dailyVideos)
                modelContext.insert(stitchedVideo)
                print("Stitch Video inserted \(stitchedVideo)")

            } else {
                let newVideo = DailyVideoEntry(filename: fileName, thumbnailFilename: thumbnailFileName)
                videos.append(newVideo)
                modelContext.insert(newVideo)
                groupVideos()
            }
                
        } catch {
            print("Error saving file \(error.localizedDescription)")
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
        let mixComposition = AVMutableComposition()
        guard let videoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            print("Error creating video track")
            return
        }
        
        
        var runningDuration: CMTime = .zero
        var instructions: [AVMutableVideoCompositionInstruction] = []
            for video in videos {
                let videoURL = video.fileURL
                let asset = AVURLAsset(url: videoURL)
                do {
                    guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                        print("no video track found")
                        continue
                    }
                    let duration = try await asset.load(.duration)
                    let timeRange = CMTimeRange(start: .zero, duration: duration)
                    try videoTrack.insertTimeRange(timeRange, of: track, at: runningDuration)
                    
                    let instruction = AVMutableVideoCompositionInstruction()
                    instruction.timeRange = CMTimeRange(start: runningDuration, duration: duration)

                    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                    layerInstruction.setTransform(try await track.load(.preferredTransform), at: runningDuration)

                    instruction.layerInstructions = [layerInstruction]
                    instructions.append(instruction)
                    
                    runningDuration = CMTimeAdd(runningDuration, duration)
                } catch {
                    print(error.localizedDescription)
                    continue
                }
            }
        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = instructions
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        // Use the render size from the first track (or max size if clips vary)
        let firstTrack = AVURLAsset(url: videos.first!.fileURL)
        do {
            guard let firstVideoTrack = try await firstTrack.loadTracks(withMediaType: .video).first else {
                print("no video track")
                return
            }
            let naturalSize = try await firstVideoTrack.load(.naturalSize)
            let transform = try await firstVideoTrack.load(.preferredTransform)
            videoComposition.renderSize = CGSize(
                width: abs(naturalSize.applying(transform).width),
                height: abs(naturalSize.applying(transform).height)
            )

        } catch {
            print(error.localizedDescription)
        }
            
            // MARK: Export
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
            
            guard let exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else {
                print("Failed to create export session")
                return
            }
            
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mov
            exportSession.videoComposition = videoComposition
            
            exportSession.exportAsynchronously { [weak self] in
                DispatchQueue.main.async {
                    switch exportSession.status {
                    case .completed:
                        self?.selectedComposedStitchVideo = ComposedStitchVideo(url: outputURL, dailyVideos: videos)
                    default:
                        print("Export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")")
                    }
                }
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
            Task {
                await  self?.combineVideos(selectedStitchVideos)
            }
        }
        
    }
}
