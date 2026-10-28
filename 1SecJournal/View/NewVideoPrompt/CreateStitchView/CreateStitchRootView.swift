//
//  CreateStitchRootView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 8/3/25.
//

import SwiftUI
import SwiftData

struct CreateStitchRootView: View {
    @EnvironmentObject var router: NavigationRouter
    @State private var viewModel: CreateStitchViewModel

    init(videos: [DailyVideoEntry],
         preselectedVideoId: UUID?,
         modelContext: ModelContext) {
        _viewModel = State(wrappedValue:
                            CreateStitchViewModel(videos: videos,
                                                  preselectedVideoId: preselectedVideoId,
                                                  modelContext: modelContext))
    }
    
    var body: some View {
        // A ZStack rather than a Group so onDisappear only fires when leaving the screen
        ZStack {
            if viewModel.previewURL != nil {
                previewView()
            } else {
                CreateStitchView(viewModel: viewModel)
                    .disabled(viewModel.isCreating)
                    .overlay {
                        if case .creating(let progress) = viewModel.creationState {
                            StitchProgressView(progress: progress,
                                               clipCount: viewModel.stitchSources.count,
                                               onCancel: viewModel.cancelStitch)
                        }
                    }
            }
        }
        .navigationBarBackButtonHidden(viewModel.isSaving)
        .overlay(alignment: .top) {
            if let errorMessage = viewModel.errorMessage {
                ToastView(message: errorMessage)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.default, value: viewModel.errorMessage)
        .task(id: viewModel.errorMessage) {
            guard viewModel.errorMessage != nil,
                  (try? await Task.sleep(for: .seconds(3))) != nil else { return }
            viewModel.errorMessage = nil
        }
        .onDisappear {
            viewModel.handleDisappear()
        }
    }

    @ViewBuilder
    private func previewView() -> some View {
        VStack {
            VideoPlayerWithDiscardOverlayView(videoURL: Binding(
                get: { viewModel.previewURL },
                set: { newValue in
                    if newValue == nil {
                        viewModel.discardStitch()
                    }
                }
            ))
            Button {
                Task {
                    if await viewModel.saveStitch() {
                        router.removeLast()
                    }
                }
            } label: {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                        .pillButtonStyle(backgroundColor: .blue)
                } else {
                    SaveButtonView()
                }
            }
            .disabled(viewModel.isSaving)
            .padding(.bottom, 8)
        }
    }
}

struct StitchProgressView: View {
    let progress: Double?
    let clipCount: Int
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Stitching \(clipCount) \(clipCount == 1 ? "video" : "videos")…")
                    .font(.headline)
                if let progress {
                    ProgressView(value: progress)
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
                Button("Cancel", role: .cancel, action: onCancel)
                    .buttonStyle(.bordered)
            }
            .padding(24)
            .frame(maxWidth: 280)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    StitchProgressView(progress: 0.42, clipCount: 12) {}
}
