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
        .sheet(isPresented: $viewModel.showCamera) {
            VideoPicker(sourceType: .camera, videoURL: $viewModel.videoURL)
        }
        .sheet(isPresented: $viewModel.showPhotoLibrary) {
            VideoPicker(sourceType: .photoLibrary, videoURL: $viewModel.videoURL)
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

struct VideoPicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    @Binding var videoURL: URL?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.mediaTypes = ["public.movie"] // Allow videos only
        picker.videoQuality = .typeHigh
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        picker.videoMaximumDuration = 10 // TODO: This is a bad UI. This just throws up an error when someone crosses the line
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: VideoPicker

        init(_ parent: VideoPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let videoURL = info[.mediaURL] as? URL {
                parent.videoURL = videoURL
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}


//#Preview {
//    NewVideoPromptView()
//}
