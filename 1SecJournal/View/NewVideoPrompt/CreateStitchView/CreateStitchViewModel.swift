//
//  CreateStitchViewModel.swift
//  1SecJournal
//
//  Created by Mike Griffin on 6/7/25.
//
import SwiftUI
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
    var videos: [VideoEntry]
    var selectedIds: Set<UUID> = []
    
    var onSelectStitchVideos: (([VideoEntry]) -> Void)
    
    init(videos: [VideoEntry], onSelectStitchVideos: @escaping ([VideoEntry]) -> Void) {
        self.videos = videos
        self.onSelectStitchVideos = onSelectStitchVideos
    }
    
    func createStitch() {
        // I guess I should show a view here that shows the video that was stitched before letting a user save
        let selectedVideos = videos.filter({ selectedIds.contains($0.id) })
        onSelectStitchVideos(selectedVideos)
    }
}
