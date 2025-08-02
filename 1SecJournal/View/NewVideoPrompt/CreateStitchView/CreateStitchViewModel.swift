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

@Observable
class CreateStitchViewModel {
    var selectedTimeFrame: StitchTimeframe = .custom {
        didSet {
            selectedIds.removeAll() // could also map them in a dictionary instead
            // meaning I could keep different selected values for each time frame
        }
    }
    var videos: [DailyVideoEntry]
    var preselectedVideoIds: [UUID] = []
    var selectedIds: Set<UUID> = []
    var modelContext: ModelContext
        
    init(videos: [DailyVideoEntry],
         preselectedVideoId: UUID? = nil,
         modelContext: ModelContext) {
        self.videos = videos
        self.modelContext = modelContext

        if let preselectedVideoId {
            selectedIds.insert(preselectedVideoId)
        }
    }
    
    func createStitch() {
        // I guess I should show a view here that shows the video that was stitched before letting a user save
        let selectedVideos = videos.filter({ selectedIds.contains($0.id) })
        
        // Detached Task I don't think is great.
        Task.detached(priority: .userInitiated) {
            await self.combineVideos(selectedVideos)
        }
    }
    
    func combineVideos(_ videos: [DailyVideoEntry]) async {
        let videos = videos.sorted(by: { $0.date < $1.date })
        if let outputURL = await AVManager.combineVideos(videos: videos) {
            let selectedComposedStitchVideo = ComposedStitchVideo(url: outputURL, dailyVideos: videos)
            
            guard let (fileName, thumbnailFileName) = await VideoFileManager.generateVideoFileURLs(url: selectedComposedStitchVideo.url) else {
                return
            }

                    let stitchedVideo = StitchedVideoEntry(filename: fileName, thumbnailFilename: thumbnailFileName, composingVideos: videos)
                    modelContext.insert(stitchedVideo)
                    AppLogger.log("Stitch Video inserted in modelContext \(stitchedVideo.id)")
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
