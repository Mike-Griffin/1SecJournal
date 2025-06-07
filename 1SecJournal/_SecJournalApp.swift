//
//  _SecJournalApp.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/16/25.
//

import SwiftUI

@main
struct _SecJournalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: VideoEntry.self)
        

    }
}
