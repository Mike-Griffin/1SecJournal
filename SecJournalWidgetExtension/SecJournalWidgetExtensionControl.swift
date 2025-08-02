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
            kind: "com.example.myApp.performActionButton"
        ) {
            ControlWidgetButton(action: CreateJournalEntryIntent()) {
                Label("Perform Action", systemImage: "video")
            }
        }
        .displayName("Create Video Journal")
        .description("Open 1SecJournal and create a video entry.")
    }
}

//struct SecJournalWidgetExtensionControl: ControlWidget {
//    var body: some ControlWidgetConfiguration {
//        StaticControlConfiguration(
//            kind: "com.comedichoney.-SecJournal.SecJournalWidgetExtension",
//            provider: Provider()
//        ) { value in
//            ControlWidgetToggle(
//                "Start Timer",
//                isOn: value,
//                action: StartTimerIntent()
//            ) { isRunning in
//                Label(isRunning ? "On" : "Off", systemImage: "timer")
//            }
//        }
//        .displayName("Timer")
//        .description("A an example control that runs a timer.")
//    }
//}
//
//extension SecJournalWidgetExtensionControl {
//    struct Provider: ControlValueProvider {
//        var previewValue: Bool {
//            false
//        }
//
//        func currentValue() async throws -> Bool {
//            let isRunning = true // Check if the timer is running
//            return isRunning
//        }
//    }
//}
//
//struct StartTimerIntent: SetValueIntent {
//    static let title: LocalizedStringResource = "Start a timer"
//
//    @Parameter(title: "Timer is running")
//    var value: Bool
//
//    func perform() async throws -> some IntentResult {
//        // Start / stop the timer based on `value`.
//        return .result()
//    }
//}
