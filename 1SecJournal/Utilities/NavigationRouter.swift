//
//  NavigationRouter.swift
//  1SecJournal
//
//  Created by Mike Griffin on 8/2/25.
//
import SwiftUI

enum AppTab: Hashable {
    case days
    case stitches
    /// Not a real tab: the camera button in the tab bar. Selecting it opens the recorder.
    case record
}

/// What a new stitch starts with selected
struct StitchRequest: Identifiable {
    let id = UUID()
    var preselectedIDs: Set<UUID> = []
    var timeframe: StitchTimeframe = .custom
}

@MainActor
final class NavigationRouter: ObservableObject {
    /// Plain values only. A SwiftData model's hash changes when it's first saved,
    /// which confuses NavigationStack about which screen is which
    enum Destination: Hashable {
        case videoDetail(UUID)
        case stitchDetail(UUID)
        case recoverVideos
    }

    @Published var selectedTab: AppTab = .days
    // Each tab keeps its own stack
    @Published var daysPath: [Destination] = []
    @Published var stitchesPath: [Destination] = []
    // The recorder and Create Stitch are full-screen covers, outside the stacks
    @Published var isRecorderPresented = false
    @Published var stitchRequest: StitchRequest?

    /// Pushes onto the stack of the tab that's showing
    func push(_ destination: Destination) {
        switch selectedTab {
        case .stitches:
            guard stitchesPath.last != destination else { return }
            stitchesPath.append(destination)
        case .days, .record:
            guard daysPath.last != destination else { return }
            daysPath.append(destination)
        }
    }

    func openRecorder() {
        // Only one cover can show at a time
        stitchRequest = nil
        isRecorderPresented = true
    }

    func newStitch(_ request: StitchRequest = StitchRequest()) {
        stitchRequest = request
    }
}
