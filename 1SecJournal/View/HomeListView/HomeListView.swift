//
//  HomeListView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/16/25.
//
import SwiftUI
import SwiftData
import AVKit
import IssueReporting

struct HomeListView: View {
    @Bindable var viewModel: HomeListViewModel
    @EnvironmentObject private var router: NavigationRouter
        
    @Environment(\.scenePhase) private var scenePhase
    
    init(viewModel: HomeListViewModel) {
        self._viewModel = Bindable(viewModel)
    }

    var body: some View {
        VStack {
            videoTypePicker()
            VStack {
                    List {
                        if viewModel.videoListDisplayType == .daily {
                            todayCreatePromptView()
                            dailyListView()
                        } else {
                            stitchedListView()
                        }
                }
                    .listStyle(.plain)
                    .scrollIndicators(.hidden)
                

            }
            Spacer()
            HStack {
                Spacer()
                Button {
                    router.push(.videoRecorder)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button("Export Backup", systemImage: "externaldrive") {
                        viewModel.exportBackup()
                    }
                    .disabled(viewModel.isPreparingBackup)
                    Button("Recover Videos", systemImage: "arrow.uturn.backward.circle") {
                        router.push(.recoverVideos)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    router.push(NavigationRouter.Destination.createStitch(videos: viewModel.videos))

                } label: {
                    Image(systemName: "folder.badge.plus")
                }
            }
        }
        .sheet(item: $viewModel.createPromptType)  { _ in
            // I should change this to pass in the HomeListViewModel rather than the prompt view model
            NewVideoPromptView(viewModel: viewModel.makeMakePromptViewModel())
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.resizes)
        }
        .sheet(item: $viewModel.selectedShareURL) { video in
            ShareSheet(activityItems: ["Check out my daily vids, bruh.", video.url])
        }
        .confirmationDialog(
            viewModel.pendingDeletion?.video is StitchedVideoEntry ? "Delete this stitch?" : "Delete this video?",
            isPresented: Binding(
                get: { viewModel.pendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.pendingDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible,
            presenting: viewModel.pendingDeletion
        ) { deletion in
            Button("Delete", role: .destructive) {
                viewModel.confirmDelete(deletion)
            }
        } message: { deletion in
            Text(deletion.message)
        }
        .sheet(item: $viewModel.backupShareURL) { backup in
            ShareSheet(activityItems: [backup.url])
        }
        .overlay {
            if viewModel.isPreparingBackup {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Preparing backup…")
                            .font(.headline)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
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
                  (try? await Task.sleep(for: .seconds(4))) != nil else { return }
            viewModel.errorMessage = nil
        }
        .navigationTitle("All Videos")
        
        .onAppear {
            for video in viewModel.videos {
                AppLogger.log("Checking... \(video.fileURL)", level: .verbose)
                if FileManager.default.fileExists(atPath: video.fileURL.path()) {
                    AppLogger.log("yes file exists \(video.fileURL)", level: .verbose)
                } else {
                    reportIssue("File does not exist at url \(video.fileURL)")
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refresh()
            }
        }
    }

    struct VideoRowCell:  View {
        @Bindable var viewModel: HomeListViewModel
        @EnvironmentObject var router: NavigationRouter
        let video: VideoEntry
        
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
                Text(video.listDisplayText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.leading, 8)
                Spacer()
                Menu {
                    Button("Stitch to New Video") {
//                        router.path.append(NavigationRouter.Destination.createStitch(videos: viewModel.videos, preselectedId: video.id))
                        router.push(.createStitch(videos: viewModel.videos, preselectedId: video.id))
                    }
                    
                    Button("Share") {
                        viewModel.setShareURL(video)
                    }
                    Button("Delete", role: .destructive) {
                        viewModel.requestDelete(video)
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
    
    private func openDetail(_ video: VideoEntry) {
        if video is StitchedVideoEntry {
            router.push(.stitchDetail(video.id))
        } else {
            router.push(.videoDetail(video.id))
        }
    }
    
    @ViewBuilder
    func videoTypePicker() -> some View {
        Picker("Select Video typs", selection: $viewModel.videoListDisplayType) {
            ForEach (VideoListDisplayType.allCases, id: \.self) { displayType in
                Text(displayType.rawValue)
            }
        }
        .pickerStyle(.segmented)
    }
    
    @ViewBuilder
    func todayCreatePromptView() -> some View {
        if viewModel.shouldShowTodayPrompt() {
            TapToRecordView(text: "Upload a video for today", height: 140)
                .onTapGesture {
                    viewModel.uploadTodayVideoCTATapped = true
                    viewModel.createPromptType = .recordOnly // consider just going directly to the camera
                }
        }
    }
    
    @ViewBuilder
    func dailyListView() -> some View {
        ForEach(viewModel.sectionedVideos, id: \.section) { section, videos in
            Section(header: Text(section.title)) {
                ForEach(videos) { video in
                    VideoRowCell(
                        viewModel: viewModel,
                        video: video)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        openDetail(video)
                    }
                }
                // Per section, so the offsets index into this section's videos
                .onDelete { offsets in
                    if let index = offsets.first {
                        viewModel.requestDelete(videos[index])
                    }
                }
            }
            .listRowInsets(EdgeInsets())
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    func stitchedListView() -> some View {
        ForEach(viewModel.stitchVideos, id: \.id) { video in
            VideoRowCell(
                viewModel: viewModel,
                video: video)
            .contentShape(Rectangle())
            .onTapGesture {
                openDetail(video)
            }
        }
        .onDelete { offsets in
            if let index = offsets.first {
                viewModel.requestDelete(viewModel.stitchVideos[index])
            }
        }
    }
}


