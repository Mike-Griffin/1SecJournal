//
//  VideoCreationRootView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 7/30/25.
//

import SwiftUI

struct VideoCreationRootView: View {
    @EnvironmentObject var router: NavigationRouter
    @Bindable var viewModel: VideoCreationRootViewModel
    
    var body: some View {
        if viewModel.videoURL == nil {
            VideoRecorderView(videoURL: $viewModel.videoURL)
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
