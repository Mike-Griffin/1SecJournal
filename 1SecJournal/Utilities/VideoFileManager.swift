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
            var thumbnailFileName = ""
            if let thumbnailImage = await AVManager.getThumbnail(from: destinationURL) {
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
                
                return (fileName, thumbnailFileName)

            }
        } catch {
            reportIssue("Error saving file \(error.localizedDescription)")
        }
        
        reportIssue("returning nil from generateVideoFileURLs")
        return nil
    }
}
