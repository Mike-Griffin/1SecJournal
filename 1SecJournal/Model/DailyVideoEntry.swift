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
    var stitchedVideos: [StitchedVideoEntry] = []
    
    override init(filename: String, thumbnailFilename: String) {
        super.init(filename: filename, thumbnailFilename: thumbnailFilename)
    }
    


}

//extension DailyVideoEntry: ListDisplayable {
//    var listDisplayText: String {
//        date.videoFormattedDisplay
//    }
//    
//    
//}
//
//extension DailyVideoEntry {
//    var listDisplayText: String {
//        date.videoFormattedDisplay
//    }
//}
