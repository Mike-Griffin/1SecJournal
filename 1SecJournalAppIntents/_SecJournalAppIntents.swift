//
//  _SecJournalAppIntents.swift
//  1SecJournalAppIntents
//
//  Created by Mike Griffin on 7/26/25.
//

import AppIntents

struct CreateJournalAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateJournalEntryIntent(),
            phrases: [
                "Create a \(.applicationName) journal entry"
            ],
            shortTitle: "Create a Journal Entry",
            systemImageName: "video"
        )
    }
}

extension Notification.Name {
    static let openVideoRecorder = Notification.Name("openVideoRecorder")
}

struct CreateJournalEntryIntent: AppIntent {
    static var title: LocalizedStringResource { "Create a 1 Second Video Journal" }
    static var description = IntentDescription("Creates a new 1-second video journal entry.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        Task { @MainActor in
            NotificationCenter.default.post(name: .openVideoRecorder, object: nil)
        }

        return .result()
    }
}
