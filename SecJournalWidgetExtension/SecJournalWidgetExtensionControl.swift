//
//  SecJournalWidgetExtensionControl.swift
//  SecJournalWidgetExtension
//
//  Created by Mike Griffin on 7/26/25.
//

import AppIntents
import SwiftUI
import WidgetKit

struct PerformActionButton: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.comedichoney.1SecJournal.createJournalEntry"
        ) {
            ControlWidgetButton(action: CreateJournalEntryIntent()) {
                Label("Record Video", systemImage: "video")
            }
        }
        .displayName("Create Video Journal")
        .description("Open 1SecJournal and create a video entry.")
    }
}
