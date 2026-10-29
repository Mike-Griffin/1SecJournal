//
//  VideoCreationRootView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 7/30/25.
//

import SwiftUI
import SwiftData

struct VideoCreationRootView: View {
    @EnvironmentObject var router: NavigationRouter
    // Owned here so redrawing the navigation destination can't swap in a new view model
    // while the camera is open, which left the finished recording with the old one
    @State private var viewModel: VideoCreationRootViewModel

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: VideoCreationRootViewModel(modelContext))
    }
    
    var body: some View {
        if viewModel.videoURL == nil {
            VideoRecorderView(videoURL: $viewModel.videoURL) {
                router.removeLast()
            }
        } else {
            VStack {
                VideoPlayerWithDiscardOverlayView(videoURL: $viewModel.videoURL)
                Button {
                    Task { @MainActor in
                        await viewModel.saveVideo()
                        router.removeLast()
                    }
                } label: {
                    Text("Temp save")
                        .pillButtonStyle(backgroundColor: .teal)

                }
            }
        }
    }
}
