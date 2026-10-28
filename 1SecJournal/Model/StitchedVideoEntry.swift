//
//  StitchedVideoEntry.swift
//  1SecJournal
//
//  Created by Mike Griffin on 6/21/25.
//

import SwiftData
import Foundation

@available(iOS 26.0, *)
@Model
class StitchedVideoEntry: VideoEntry {
    /// IDs of the daily videos in this stitch, oldest first. Stored as IDs rather than a
    /// relationship because SwiftData (iOS 26.1) crashes keeping a many-to-many relationship
    /// between two subclasses in sync. A video can be in any number of stitches.
    var sourceVideoIDs: [UUID] = []
    /// Dates of the first and last source videos, kept so the stitch still
    /// describes its range after a source video is deleted
    var rangeStart: Date?
    var rangeEnd: Date?
    
    init(filename: String, thumbnailFilename: String, composingVideos: [DailyVideoEntry]) {
        let sources = composingVideos.sorted { $0.date < $1.date }
        self.sourceVideoIDs = sources.map(\.id)
        self.rangeStart = sources.first?.date
        self.rangeEnd = sources.last?.date
        super.init(filename: filename, thumbnailFilename: thumbnailFilename)
    }
    
   override var listDisplayText: String {
       guard let rangeStart, let rangeEnd else {
           // A stitch whose sources were lost before ranges were saved
           return super.listDisplayText
       }
       return "\(rangeStart.videoFormattedDisplay) - \(rangeEnd.videoFormattedDisplay)"
   }
}
