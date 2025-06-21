//
//  _SecJournalApp.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/16/25.
//

import SwiftUI
import SwiftData

@main
struct _SecJournalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .applyModelContainer()
        }
    }
}

extension View {
    @ViewBuilder
    func applyModelContainer() -> some View {
        if #available(iOS 26.0, *) {
            self.modelContainer(for: [VideoEntry.self, DailyVideoEntry.self, StitchedVideoEntry.self])
        } else {
            // Fallback — older versions don't have access to subclasses
            self.modelContainer(for: [VideoEntry.self])
        }
    }
}
