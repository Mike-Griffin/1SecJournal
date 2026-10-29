//
//  ContentView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/16/25.
//

import SwiftUI



struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var router = NavigationRouter()
    // Created once in onAppear; modelContext isn't available in init
    @State private var homeViewModel: HomeListViewModel?

    var body: some View {
        NavigationStack(path: $router.navigationStack) {
            Group {
                if let homeViewModel {
                    HomeListView(viewModel: homeViewModel)
                }
            }
                .navigationDestination(for: NavigationRouter.Destination.self) { destination in
                    switch destination {
                    case .videoRecorder:
                        VideoCreationRootView(modelContext: modelContext)
                            .navigationBarBackButtonHidden()
                    case .createStitch(let videos, let preselectedId):
                        CreateStitchRootView(videos: videos, preselectedVideoId: preselectedId, modelContext: modelContext)
                    case .videoDetail(let id):
                        DailyVideoDetailView(videoID: id)
                    case .stitchDetail(let id):
                        StitchDetailView(stitchID: id)
                    case .recoverVideos:
                        RecoverVideosView(modelContext: modelContext)
                    }
                }
                .onReceive( NotificationCenter.default.publisher(for: .openVideoRecorder)) {  _ in
                    Task { @MainActor in
                        AppLogger.log("Setting pending destination")
                        router.push(.videoRecorder)
                    }
                }
        }
        .environmentObject(router)
        .onAppear {
            if homeViewModel == nil {
                homeViewModel = HomeListViewModel(modelContext)
            }
        }
        .onChange(of: router.navigationStack) { oldStack, newStack in
            // Refresh as soon as a screen pops (e.g. after saving a video) so Home has the
            // new data before its transition starts, instead of changing mid-animation
            if newStack.count < oldStack.count {
                homeViewModel?.refresh()
            }
        }
    }
}

#Preview {
    ContentView()
}
