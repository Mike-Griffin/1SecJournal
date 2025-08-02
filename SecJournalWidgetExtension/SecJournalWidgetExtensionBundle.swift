//
//  SecJournalWidgetExtensionBundle.swift
//  SecJournalWidgetExtension
//
//  Created by Mike Griffin on 7/26/25.
//

import WidgetKit
import SwiftUI

@main
struct SecJournalWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        SecJournalWidgetExtension()
        PerformActionButton()
        SecJournalWidgetExtensionLiveActivity()
    }
}
