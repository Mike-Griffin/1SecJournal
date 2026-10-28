//
//  _SecJournalApp.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/16/25.
//

import SwiftUI
import SwiftData
import Intents

@main
struct _SecJournalApp: App {
    init() {
        INPreferences.requestSiriAuthorization { status in
            AppLogger.log("Siri auth status: \(status.rawValue)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [VideoEntry.self, DailyVideoEntry.self, StitchedVideoEntry.self])
        }
    }
}
