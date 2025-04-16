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
    @State private var isShowingCreatePrompt = false
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.date, order: .reverse) var videos: [JournalEntry]

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(videos, id: \.self) { video in
                        NavigationLink {
                            VideoPlayerWrapperView(video: video)
                        } label: {
                            VStack {
                                if(video.thumbnailImage != nil) {
                                    Image(uiImage: video.thumbnailImage!)
                                        .resizable()
                                                .aspectRatio(contentMode: .fit)
                                }
                                Text(video.date.videoFormattedDisplay)
                                Divider()
                                Text(video.fileURL.lastPathComponent)
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                    .onDelete(perform: deleteItem)
                }
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        isShowingCreatePrompt = true
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
            .sheet(isPresented: $isShowingCreatePrompt)  {
                NewVideoPromptView(showModal: $isShowingCreatePrompt)
                    .presentationDetents([.medium, .large])
            }
        }
        .navigationTitle("All Videos")
        .onAppear {
            for video in videos {
                print(video.fileURL)
                if FileManager.default.fileExists(atPath: video.fileURL.path()) {
                    print("yes file exists")
                } else {
                    print("no file does not exist")

                }
            }
        }
    }
    
    private func deleteItem(at offsets: IndexSet) {
        for index in offsets {
            let video = videos[index]
            modelContext.delete(video)
        }
    }
}
