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
    @Binding var showModal: Bool
    @State private var viewModel: NewVideoPromptViewModel
    
    @Environment(\.modelContext) private var modelContext
    
    init(showModal: Binding<Bool>) {
        self._showModal = showModal
        
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: JournalEntry.self, configurations: configuration)
        let placeholderContext = container.mainContext
        self._viewModel = State(wrappedValue: NewVideoPromptViewModel(modelContext: placeholderContext))

    }

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    showModal = false
                } label: {
                    Image(systemName: "x.circle")
                        .font(.system(size: 24)) // Large and bold plus icon
                        .foregroundStyle(.black)
                }
            }
            .padding()
            Spacer()
            if let videoURL = viewModel.videoURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: 300)
                    .cornerRadius(10)
                    .padding()
            } else {
                Text("No video selected")
                    .foregroundColor(.gray)
                    .padding()
            }
            if viewModel.videoURL != nil {
                Button {
                    viewModel.saveVideo()
                    showModal = false
                } label: {
                    Text("Save")
                }
            } else {
                VideoPickerSelectionButtons(viewModel: viewModel)
            }
            Spacer()
        }
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            VideoRecorderView(videoURL: $viewModel.videoURL)
//            VideoPickerView(sourceType: .camera, videoURL: $viewModel.videoURL)
        }
        .sheet(isPresented: $viewModel.showPhotoLibrary) {
            // TODO: Can remove the photoLibrary type
            VideoPickerView(sourceType: .photoLibrary, videoURL: $viewModel.videoURL)
        }
        .onAppear {
            if viewModel.modelContext !== modelContext {
                viewModel = NewVideoPromptViewModel(modelContext: modelContext)
            }
        }
    }

}

struct VideoPickerSelectionButtons: View {
    var viewModel: NewVideoPromptViewModel
    var body: some View {
        HStack {
            Button("Record Video") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    viewModel.showCamera = true
                } else {
                    print("Camera not available")
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
            
            Button("Choose from Library") {
                viewModel.showPhotoLibrary = true
            }
            .buttonStyle(.bordered)
            .padding()
        }
    }
}




//#Preview {
//    NewVideoPromptView()
//}
