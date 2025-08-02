//
//  VideoCreationRootViewModel.swift
//  1SecJournal
//
//  Created by Mike Griffin on 7/30/25.
//

import SwiftUI
import SwiftData

@MainActor
@Observable class VideoCreationRootViewModel {
    var videoURL: URL? // I want to call saveVideo which is what HomeListViewModel does

    var modelContext: ModelContext

    init(_ modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func saveVideo() async {
        // probably should handle this differently, make this async, put the task in the callsite
//        Task {
            guard let videoURL,
                  let (fileName, thumbnailFileName) = await VideoFileManager.generateVideoFileURLs(url: videoURL) else {
                return
            }
            
            let newVideo = DailyVideoEntry(filename: fileName, thumbnailFilename: thumbnailFileName)
            modelContext.insert(newVideo)
        //}
    }
}
