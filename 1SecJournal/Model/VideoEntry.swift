//
//  VideoEntry.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/22/25.
//
import SwiftData
import UIKit

// Every attribute has a default and relationships are optional, which keeps the
// model compatible with CloudKit sync if it's ever turned on
@Model class VideoEntry {
    var id: UUID = UUID()
    var filename: String = ""
    var thumbnailFilename: String = ""
    var date: Date = Date() // date video is created
    var title: String?
    var journalText: String?
    /// When the title or journal text last changed
    var updatedAt: Date?
    
    init(filename: String, thumbnailFilename: String) {
        self.id = UUID()
        self.filename = filename
        self.thumbnailFilename = thumbnailFilename
        self.date = Date()
    }
    
    var listDisplayText: String {
        return date.videoFormattedDisplay
    }
}

extension VideoEntry {
    var fileURL: URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup) else {
            AppLogger.log("invalid containerURL")
            return URL(filePath: "")
        }
        return containerURL.appendingPathComponent(filename)
    }
    
    var thumbnailImage: UIImage? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup) else {
            return nil
        }
        let thumbnailURL = containerURL.appendingPathComponent(thumbnailFilename)
        return UIImage(contentsOfFile: thumbnailURL.path)
    }
    

}
