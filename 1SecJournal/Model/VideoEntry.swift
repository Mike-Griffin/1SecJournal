//
//  VideoEntry.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/22/25.
//
import SwiftData
import Foundation

@Model class JournalEntry {
    var id: UUID
    var filename: String
    var date: Date
    
    init(filename: String) {
        self.id = UUID()
        self.filename = filename
        self.date = Date()
    }
}

extension JournalEntry {
    var fileURL: URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup) else {
            print("invalid containerURL")
            return URL(filePath: "")
        }
        return containerURL.appendingPathComponent(filename)
    }
}
