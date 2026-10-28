//
//  VideoFileManager.swift
//  1SecJournal
//
//  Created by Mike Griffin on 6/22/25.
//
import Foundation
import IssueReporting

struct VideoFileManager {
    static func generateVideoFileURLs(url: URL) async -> (String, String)? {
        let uuidString = UUID().uuidString
        
        let fileName = uuidString + ".mov"
        
        // Get the Documents directory
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup) else {
            reportIssue("invalid containerURL")
            return nil
        }
        let destinationURL = containerURL.appendingPathComponent(fileName)
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path()) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.copyItem(at: url, to: destinationURL)
            AppLogger.log("Video saved to: \(destinationURL)")
            
            guard let thumbnailImage = await AVManager.getThumbnail(from: destinationURL),
                  let data = thumbnailImage.jpegData(compressionQuality: 0.8) else {
                // Without a thumbnail there's no entry, so don't keep the copied video either
                try? FileManager.default.removeItem(at: destinationURL)
                reportIssue("Failed to create a thumbnail for \(fileName)")
                return nil
            }
            let thumbnailFileName = uuidString + "thumb.jpg"
            let thumbDestinationURL = containerURL.appendingPathComponent(thumbnailFileName)
            try data.write(to: thumbDestinationURL, options: .atomic)
            return (fileName, thumbnailFileName)
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            reportIssue("Error saving file \(error.localizedDescription)")
            return nil
        }
    }
}
