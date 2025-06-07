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
//    var videoURL: URL?
    var showCamera = false
    var showPhotoLibrary = false
    
    var onSave: (URL) -> Void
    var onDismiss: (() -> Void)
    
    init(onDismiss: @escaping () -> Void,
         onSave: @escaping (URL) -> Void) {
        self.onDismiss = onDismiss
        self.onSave = onSave
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
}
