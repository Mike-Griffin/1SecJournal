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

    var body: some View {
        NavigationStack(path: $router.navigationStack) {
            HomeListView(viewModel: HomeListViewModel(modelContext))
                .navigationDestination(for: NavigationRouter.Destination.self) { destination in
                    switch destination {
                    case .videoRecorder:
                        VideoCreationRootView(viewModel: VideoCreationRootViewModel(modelContext))
                            .navigationBarBackButtonHidden()
                    case .createStitch(let videos, let preselectedId):
                        CreateStitchRootView(videos: videos, preselectedVideoId: preselectedId, modelContext: modelContext)
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
    }
}

#Preview {
    ContentView()
}
