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
    var url: URL
    var date: Date
    
    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.date = Date()
    }
}
