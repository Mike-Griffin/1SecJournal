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

struct ShareItem: Identifiable, CustomStringConvertible {
    let id = UUID()
    let url: URL

    var description: String { "" } // prevents UUID or file path from flashing on sheet
}

@Observable class HomeListViewModel {
    // Video Display
    var videos: [VideoEntry] = []
    var sectionedVideos: [(section: VideoSection, videos: [VideoEntry])] = []
    
    // Share Sheet
    var selectedShareURL: ShareItem?
    
    // Prompt Management
    var createPromptType: CreatePromptType?
    var uploadTodayVideoCTATapped: Bool = false
    
    var modelContext: ModelContext
    
    init(_ modelContext: ModelContext) {
        self.modelContext = modelContext
        handleFetchAndGroupVideos()
    }
    
    func handleEnterForeground() {
        handleFetchAndGroupVideos()
    }
    
    func handleFetchAndGroupVideos() {
        fetchVideos()
        groupVideos()
    }
    
    private func fetchVideos() {
        do {
            let descriptor = FetchDescriptor<VideoEntry>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            self.videos = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch videos: \(error)")
        }
    }
    
    private func groupVideos() {
        var groupedVideos: [VideoSection: [VideoEntry]] = [:]

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

    
    private func getThumbnail(from videoURL: URL) -> UIImage? {
            let asset = AVURLAsset(url: videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true

            let time = CMTime(seconds: 1, preferredTimescale: 600) // 1 second into video
            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                return UIImage(cgImage: cgImage)
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
            selectedShareURL = ShareItem(url: targetURL)
        } catch {
            print("❌ Failed to copy file for sharing:", error)
         }
    }
    
    func deleteVideo(_ video: VideoEntry) {
        modelContext.delete(video)
    }
    
    func saveVideo(url: URL) {
        
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
            if let thumbnailImage = getThumbnail(from: destinationURL) {
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

            let newVideo = VideoEntry(filename: fileName, thumbnailFilename: thumbnailFileName)
            videos.append(newVideo)
            modelContext.insert(newVideo)
            groupVideos()
                
        } catch {
            print("Error saving file \(error.localizedDescription)")
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
        return NewVideoPromptViewModel{ [weak self] in
            self?.createPromptType = nil
        } onSave: { [weak self] url in
            self?.saveVideo(url: url)
        }
        
    }
}
