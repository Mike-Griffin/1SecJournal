//
//  NewVideoPromptView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/16/25.
//

import SwiftUI
import AVKit
import SwiftData


struct NewVideoPromptView: View {
    @Bindable private var viewModel: NewVideoPromptViewModel
//    @EnvironmentObject var router: NavigationRouter
    let showStitch: Bool
    
    
    init(viewModel: NewVideoPromptViewModel, showStitch: Bool) {
        self._viewModel = Bindable(wrappedValue: viewModel)
        self.showStitch = showStitch
    }

    var body: some View {
        VStack {
            PromptHeaderView(viewModel: viewModel)
            Spacer()
            VideoInformationView(viewModel: viewModel, showStitch: showStitch)
                .padding(.horizontal)
                .frame(height: 300)
            if viewModel.videoURL != nil {
                PersistenceFooterControls(viewModel: viewModel)
                    .padding(.top, 8)
            }
            Spacer()
        }
//        .fullScreenCover(isPresented: $viewModel.showCamera) {
//            VideoRecorderView(videoURL: $viewModel.videoURL)
//        }
        .sheet(isPresented: $viewModel.showPhotoLibrary) {
            // TODO: Can remove the photoLibrary type
            VideoPickerView(sourceType: .photoLibrary, videoURL: $viewModel.videoURL)
        }
        .sheet(isPresented: $viewModel.showCreateStitch) {
//            CreateStitchView(viewModel: viewModel.createStitchViewModel())
        }
    }

}

struct PromptHeaderView: View {
    @Bindable var viewModel: NewVideoPromptViewModel
    var body: some View {
        VStack {
            Spacer().frame(height: 12)
            HStack {
                Spacer()
                Text("Save Today's Memory")
                    .font(.headline)
                    .padding(.top, 4)
                
                Spacer()
                Button {
                    viewModel.dismissPrompt()
                } label: {
                    Image(systemName: "x.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(.primary)
                        .tint(.primary)
                }
            }
        }
        .padding(.horizontal)
        .zIndex(1)
    }
}

struct VideoInformationView: View {
    @Bindable var viewModel: NewVideoPromptViewModel
    @EnvironmentObject var router: NavigationRouter // Should I pass this into viewModel
    let showStitch: Bool
    var body: some View {
        VStack  {
            if let player = viewModel.player {
                ZStack {
                    VideoPlayer(player: player)
                        .aspectRatio(9/16, contentMode: .fill)
                        .frame(height: 300)
                        .clipped()
                        .cornerRadius(10)
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.black.opacity(0.6), Color.black.opacity(0.3)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                                    .blur(radius: 0)
                                
                                Button {
                                    viewModel.videoURL = nil
                                } label: {
                                    Image(systemName: "trash.circle")
                                        .resizable()
                                        .frame(width: 36, height: 36)
                                        .foregroundStyle(.white)
                                        .padding()
                                }
                            }
                            Spacer()
                        }
                    }
                }

            } else {
                VStack(spacing: 8) {
                    TapToRecordView(text: "Tap to record", height: 260)
                        .onTapGesture {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Task { @MainActor in
//                                    router.path.append(NavigationRouter.Destination.videoRecorder)
                                    router.push(.videoRecorder)
                                }
                            } else {
                                AppLogger.log("Camera not available")
                            }
                        }
                    if showStitch {
                        Button {
                            viewModel.showCreateStitch = true
                        } label: {
                            ZStack {
                                Text("Create Stitch")
                                    .tint(.primary)
                                Capsule()
                                    .fill(Color.gray.opacity(0.2))
                                
                            }
                            .padding()
                            .frame(width: 260, height: 80)
                            
                        }
                    }
                }
            }
        }
        
        
    }
}

struct PersistenceFooterControls: View {
    @Bindable var viewModel: NewVideoPromptViewModel
    var body: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.saveVideo()
                viewModel.dismissPrompt()
            } label: {
                SaveButtonView()
            }
        }
    }
}
