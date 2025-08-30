//
//  CreateStitchRootView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 8/3/25.
//

import SwiftUI
import SwiftData

struct CreateStitchRootView: View {
//    let videos: [DailyVideoEntry]
//    let preselectedVideoId: UUID?
//    let modelContext: ModelContext
    @EnvironmentObject var router: NavigationRouter
    @State private var viewModel: CreateStitchViewModel
//    @Environment(\.dismiss) var dismiss


    init(videos: [DailyVideoEntry],
         preselectedVideoId: UUID?,
         modelContext: ModelContext) {
        _viewModel = State(wrappedValue:
                            CreateStitchViewModel(videos: videos,
                                                  preselectedVideoId: preselectedVideoId,
                                                  modelContext: modelContext))
    }
    
    var body: some View {
        if viewModel.stitchVideoUrl == nil  {
            CreateStitchView(viewModel: viewModel)
        } else {
            VideoPlayerWithDiscardOverlayView(videoURL: $viewModel.stitchVideoUrl)
            Button {
                viewModel.saveCreatedStich()
                router.removeLast()
            } label: {
                Text("Temp Save")
                    .pillButtonStyle(backgroundColor: .mint)
            }
        }
    }
}
