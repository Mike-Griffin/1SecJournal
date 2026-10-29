//
//  ContentView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/16/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var router = NavigationRouter()
    // Created once in onAppear; modelContext isn't available in init
    @State private var homeViewModel: HomeListViewModel?

    var body: some View {
        Group {
            if let homeViewModel {
                tabs(homeViewModel)
            } else {
                // Something has to appear for onAppear to run and create the view model
                Color.clear
            }
        }
        .environmentObject(router)
        .onAppear {
            if homeViewModel == nil {
                homeViewModel = HomeListViewModel(modelContext)
            }
        }
    }

    private func tabs(_ viewModel: HomeListViewModel) -> some View {
        TabView(selection: tabSelection) {
            Tab("Days", systemImage: "square.grid.2x2", value: AppTab.days) {
                NavigationStack(path: $router.daysPath) {
                    DaysView(viewModel: viewModel)
                        .appDestinations()
                }
            }
            Tab("Stitches", systemImage: "film.stack", value: AppTab.stitches) {
                NavigationStack(path: $router.stitchesPath) {
                    StitchesView(viewModel: viewModel)
                        .appDestinations()
                }
            }
            // The search role puts the tab in its own circle at the end of the tab bar,
            // so the camera is one tap away on every screen
            Tab("Record", systemImage: "camera.fill", value: AppTab.record, role: .search) {
                Color.clear
            }
        }
        .homeChrome(viewModel)
        .fullScreenCover(isPresented: $router.isRecorderPresented, onDismiss: viewModel.refresh) {
            VideoCreationRootView(modelContext: modelContext)
        }
        .fullScreenCover(item: $router.stitchRequest, onDismiss: viewModel.refresh) { request in
            NavigationStack {
                CreateStitchRootView(request: request, modelContext: modelContext)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openVideoRecorder)) { _ in
            router.openRecorder()
        }
        // Refresh as soon as a screen pops so Home has the new data before its transition starts
        .onChange(of: router.daysPath.count) { oldCount, newCount in
            if newCount < oldCount { viewModel.refresh() }
        }
        .onChange(of: router.stitchesPath.count) { oldCount, newCount in
            if newCount < oldCount { viewModel.refresh() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { viewModel.refresh() }
        }
    }

    /// Selecting the camera tab opens the recorder and leaves the current tab selected
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { router.selectedTab },
            set: { newTab in
                if newTab == .record {
                    router.openRecorder()
                } else {
                    router.selectedTab = newTab
                }
            }
        )
    }
}

private extension View {
    func appDestinations() -> some View {
        navigationDestination(for: NavigationRouter.Destination.self) { destination in
            DestinationView(destination: destination)
        }
    }
}

private struct DestinationView: View {
    @Environment(\.modelContext) private var modelContext
    let destination: NavigationRouter.Destination

    var body: some View {
        switch destination {
        case .videoDetail(let id):
            DailyVideoDetailView(videoID: id)
        case .stitchDetail(let id):
            StitchDetailView(stitchID: id)
        case .recoverVideos:
            RecoverVideosView(modelContext: modelContext)
        }
    }
}

#Preview {
    ContentView()
}
