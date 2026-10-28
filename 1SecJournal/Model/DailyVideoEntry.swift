//
//  DailyVideoEntry.swift
//  1SecJournal
//
//  Created by Mike Griffin on 6/21/25.
//
import SwiftData
import Foundation

@available(iOS 26.0, *)
@Model
class DailyVideoEntry: VideoEntry {
    // The stitches a video is part of are found through StitchedVideoEntry.sourceVideoIDs
    
    override init(filename: String, thumbnailFilename: String) {
        super.init(filename: filename, thumbnailFilename: thumbnailFilename)
    }
}
