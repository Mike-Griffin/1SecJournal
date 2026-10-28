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
    @State var testUrl: URL? = URL(fileURLWithPath: "/path/to/file")
    @AppStorage("launchDestination") private var launchDestination: String?


    var body: some View {
        NavigationStack(path: $router.navigationStack) {
            HomeListView(viewModel: HomeListViewModel(modelContext))
                .navigationDestination(for: NavigationRouter.Destination.self) { destination in
                    switch destination {
                    case .home:
                        HomeListView(viewModel: HomeListViewModel(modelContext))
                    case .videoRecorder:
                        VideoCreationRootView(viewModel: VideoCreationRootViewModel(modelContext))
                            .navigationBarBackButtonHidden()
                    case .createStitch(let videos, let preselectedId):
                        CreateStitchRootView(videos: videos, preselectedVideoId: preselectedId, modelContext: modelContext) // TODO: Remove the onSelectStitchVideos
/*                        CreateStitchView(viewModel: CreateStitchViewModel(videos: videos, preselectedVideoId: preselectedId, onSelectStitchVideos: {_ in}))*/ // TODO: Remove the onSelectStitchVideos
                    }
                }
//                .task {
//                    await handleLaunchDestination()
//                }
                .onReceive( NotificationCenter.default.publisher(for: .openVideoRecorder)) {  _ in
                    Task { @MainActor in
                        AppLogger.log("Setting pending destination")
                        router.push(.videoRecorder)
                    }
                }
                .onAppear {
                    // TODO: This doesn't seem to be helping
                    // CameraPreloader.shared.preload()
                }
        }
        .environmentObject(router)
    }
    
    @MainActor
    func handleLaunchDestination() async {
        if launchDestination == "videoRecorder" {
            router.push(.videoRecorder)
            launchDestination = nil
        }
    }
}

#Preview {
    ContentView()
}
