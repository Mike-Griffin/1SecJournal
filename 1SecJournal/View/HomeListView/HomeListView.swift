//
//  HomeListView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/16/25.
//
import SwiftUI
import SwiftData
import AVKit

struct HomeListView: View {
    @Bindable var viewModel: HomeListViewModel
    @State private var tappedVideo: VideoEntry? = nil
        
    @Environment(\.scenePhase) private var scenePhase
    
    init(viewModel: HomeListViewModel) {
        self._viewModel = Bindable(viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    if viewModel.shouldShowTodayPrompt() {
                        TapToRecordView(text: "Upload a video for today", height: 140)
                            .onTapGesture {
                                viewModel.uploadTodayVideoCTATapped = true
                                viewModel.createPromptType = .recordOnly // consider just going directly to the camera
                            }
                    }
                    ForEach(viewModel.sectionedVideos, id: \.section) { section, videos in
                        Section(header: Text(section.title)) {
                            ForEach(videos) { video in
                                VideoRowCell(
                                    viewModel: viewModel,
                                    video: video)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        tappedVideo = video
                                    }
                            }
                        }
                        .listRowInsets(EdgeInsets())
                    }
                    .onDelete(perform: deleteItem)
                }
                .listStyle(.plain)
                .navigationDestination(item: $tappedVideo) { video in
                    VideoPlayerWrapperView(video: video)
                }
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        viewModel.createPromptType = .recordAndStitch
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 40, weight: .bold)) // Large and bold plus icon
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80) // Ensures the button is large enough
                            .background(Circle().fill(Color.blue)) // Circular shape with blue color
                            .shadow(radius: 5)
                    }
                }
                .padding(.trailing, 12)
                
            }
            .padding()
            .sheet(item: $viewModel.createPromptType)  { createType in
                // I should change this to pass in the HomeListViewModel rather than the prompt view model
                NewVideoPromptView(viewModel: viewModel.makeMakePromptViewModel(),
                                   showStitch: createType == .recordAndStitch)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationContentInteraction(.resizes)
            }
            .sheet(item: $viewModel.selectedShareURL) { video in
                ShareSheet(activityItems: ["Check out my daily vids, bruh.", video.url])
            }
            .navigationTitle("All Videos")
            
        }
        .onAppear {
            for video in viewModel.videos {
                print(video.fileURL)
                if FileManager.default.fileExists(atPath: video.fileURL.path()) {
                    print("yes file exists")
                } else {
                    print("no file does not exist")

                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.handleEnterForeground()
            }
        }
    }

    struct VideoRowCell:  View {
        @Bindable var viewModel: HomeListViewModel
        let video: VideoEntry
//        @Binding var isSharedSheetPresented: Bool
        
        let thumbnailHeight = 142.0
        let thumbnailWidth = 80.0
        
        var body: some View {
            HStack(spacing: 16) {
                if(video.thumbnailImage != nil) {
                    Image(uiImage: video.thumbnailImage!)
                        .resizable()
                        .aspectRatio(9/16, contentMode: .fill)
                        .frame(width: thumbnailWidth, height: thumbnailHeight)
                        .clipped()
                        .cornerRadius(8)
                }
                Text(video.date.videoFormattedDisplay)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.leading, 8)
                Spacer()
                Menu {
                    Button("Stitch to New Video") {
                        // Handle stitching
                    }
                    
                    Button("Share") {
                        viewModel.setShareURL(video)
                    }
                    Button("Delete", role: .destructive) {
                        viewModel.deleteVideo(video)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                        .contentShape(Rectangle())
                        .frame(maxHeight: .infinity)
                        .padding(.trailing, 8)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func deleteItem(at offsets: IndexSet) {
        for index in offsets {
            let video = viewModel.videos[index]
            viewModel.deleteVideo(video)
        }
    }
    

}
