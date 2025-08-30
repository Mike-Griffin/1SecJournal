//
//  VideoEntry.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/22/25.
//
import SwiftData
import UIKit

//protocol ListDisplayable {
//    var listDisplayText: String { get }
//}

//@Model class VideoEntry: ListDisplayable {
@Model class VideoEntry {

    var id: UUID
    var filename: String
    var thumbnailFilename: String
    var date: Date // date video is created
//    var listDisplayText: String
    
    init(filename: String, thumbnailFilename: String) {
        self.id = UUID()
        self.filename = filename
        self.thumbnailFilename = thumbnailFilename
        self.date = Date()
    }
    
    var listDisplayText: String {
        // Default implementation
//        AppLogger.log("returning default listDisplayText")
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
