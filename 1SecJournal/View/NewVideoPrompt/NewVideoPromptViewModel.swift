//
//  NewVideoPromptViewModel.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/22/25.
//
import SwiftUI
import SwiftData
import AVFoundation

let kAppGroup = "group.com.comedichoney.1SecJournal"

@Observable class NewVideoPromptViewModel {
    var videoURL: URL?
    var showCamera = false
    var showPhotoLibrary = false
    
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
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
    
    func saveVideo() {
        guard let url = videoURL else {
            // TODO: Error handling
            return
        }
        
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

            let newVideo = JournalEntry(filename: fileName, thumbnailFilename: thumbnailFileName)
            modelContext.insert(newVideo)
                
        } catch {
            print("Error saving file \(error.localizedDescription)")
        }
        

    }
}
