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
    
   override var listDisplayText: String {
       let sortedVideos = composingVideos.sorted { $0.date < $1.date }
       guard let firstVideoDate = sortedVideos.first?.date,
             let lastVideoDate = sortedVideos.last?.date else {
           AppLogger.log("didn't get a last date or a first date", level: .warning)
           return "\(self.listDisplayText) :("
       }
       for video in sortedVideos {
           print("created video \(id) has a video on this date \(video.date)")
       }
       return "\(firstVideoDate.videoFormattedDisplay) - \(lastVideoDate.videoFormattedDisplay)"
   }
}

//extension StitchedVideoEntry {
//
//
//}
