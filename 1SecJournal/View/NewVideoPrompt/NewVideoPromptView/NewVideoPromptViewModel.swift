//
//  NewVideoPromptViewModel.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/22/25.
//
import SwiftUI
import SwiftData
import AVFoundation

//let kAppGroup = "group.com.comedichoney.1SecJournal"

@Observable class NewVideoPromptViewModel {
    var showCamera = false
    var showPhotoLibrary = false
    var showCreateStitch = false
    
    // All videos are passed down to the CreateStitchViewModel
    var videos: [DailyVideoEntry]
    
    var onSave: (URL) -> Void
    var onDismiss: (() -> Void)
    var onSelectedStitchVideos: ([DailyVideoEntry]) -> Void
    
    init(videos: [DailyVideoEntry],
        onDismiss: @escaping () -> Void,
         onSave: @escaping (URL) -> Void,
         onSelectedStitchVideos: @escaping ([DailyVideoEntry]) -> Void
    ) {
        self.onDismiss = onDismiss
        self.onSave = onSave
        self.videos = videos
        self.onSelectedStitchVideos = onSelectedStitchVideos
    }
    
    var videoURL: URL? {
        didSet {
            if let url = videoURL {
                player = AVPlayer(url: url)
            } else {
                player = nil
            }
        }
    }
    var player: AVPlayer?
    
    func saveVideo() {
        guard let url = videoURL else {
            // TODO: Error handling
            return
        }
        onSave(url)
    }
    
    func dismissPrompt() {
        onDismiss()
    }
    
//    func createStitchViewModel() -> CreateStitchViewModel {
//        CreateStitchViewModel(videos: videos) { [weak self] selectedStitchVideos in
//            self?.onDismiss()
//            self?.onSelectedStitchVideos(selectedStitchVideos)
//        }
//    }
}
