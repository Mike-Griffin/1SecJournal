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
    @Query(sort: \JournalEntry.date, order: .reverse) var videos: [JournalEntry]

    var body: some View {
        NavigationStack {
            
            VStack {
                List(videos) { video in
                    NavigationLink {
                        VideoPlayer(player: AVPlayer(url: video.url))
                            .navigationTitle("Playback")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        HStack {
                            Text(video.date.formatted(date: .abbreviated, time: .shortened))
                            Spacer()
                            Text(video.url.lastPathComponent)
                                .foregroundStyle(.gray)
                        }
                    }
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
    }
}
