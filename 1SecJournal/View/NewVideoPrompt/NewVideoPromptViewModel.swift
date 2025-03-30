//
//  NewVideoPromptViewModel.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/22/25.
//
import SwiftUI
import SwiftData

@Observable class NewVideoPromptViewModel {
    var videoURL: URL?
    var showCamera = false
    var showPhotoLibrary = false
    
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func saveVideo() {
        guard let url = videoURL else {
            // TODO: Error handling
            return
        }
        
        let newVideo = JournalEntry(url: url)
        modelContext.insert(newVideo)
    }
}
