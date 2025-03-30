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
        
        let fileName = UUID().uuidString + ".mov"
        
        // Get the Documents directory
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path()) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.copyItem(at: url, to: destinationURL)
            print("Video saved to: \(destinationURL)")

            let newVideo = JournalEntry(url: destinationURL)
            modelContext.insert(newVideo)
                
        } catch {
            print("Error saving file \(error.localizedDescription)")
        }
        

    }
}
