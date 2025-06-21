//
//  StitchedVideoEntry.swift
//  1SecJournal
//
//  Created by Mike Griffin on 6/21/25.
//

import SwiftData

@available(iOS 26.0, *)
@Model
class StitchedVideoEntry: VideoEntry {
    var composingVideos: [DailyVideoEntry]
    
    init(filename: String, thumbnailFilename: String, composingVideos: [DailyVideoEntry]) {
        self.composingVideos = composingVideos
        super.init(filename: filename, thumbnailFilename: thumbnailFilename)
    }
}
