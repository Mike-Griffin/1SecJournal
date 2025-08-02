//
//  SecJournalWidgetExtensionLiveActivity.swift
//  SecJournalWidgetExtension
//
//  Created by Mike Griffin on 7/26/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct SecJournalWidgetExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct SecJournalWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SecJournalWidgetExtensionAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension SecJournalWidgetExtensionAttributes {
    fileprivate static var preview: SecJournalWidgetExtensionAttributes {
        SecJournalWidgetExtensionAttributes(name: "World")
    }
}

extension SecJournalWidgetExtensionAttributes.ContentState {
    fileprivate static var smiley: SecJournalWidgetExtensionAttributes.ContentState {
        SecJournalWidgetExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: SecJournalWidgetExtensionAttributes.ContentState {
         SecJournalWidgetExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: SecJournalWidgetExtensionAttributes.preview) {
   SecJournalWidgetExtensionLiveActivity()
} contentStates: {
    SecJournalWidgetExtensionAttributes.ContentState.smiley
    SecJournalWidgetExtensionAttributes.ContentState.starEyes
}
