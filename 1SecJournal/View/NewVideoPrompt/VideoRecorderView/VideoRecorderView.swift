//
//  VideoPickerView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/30/25.
//
import SwiftUI
import AVFoundation

struct VideoRecorderView: UIViewControllerRepresentable {
//    @Bindable var viewModel: VideoRecorderViewModel


    // rather than have a binding of just a URL. Pass in the entire viewmodel
    @Binding var videoURL: URL?
    let onClose: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> CameraRecorderViewController {
        let controller = CameraRecorderViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraRecorderViewController, context: Context) {}

    class Coordinator: NSObject, CustomCameraViewControllerDelegate {
        let parent: VideoRecorderView

        init(parent: VideoRecorderView ) {
            self.parent = parent
        }

        func didFinishRecording(to url: URL) {
            withAnimation {
                parent.videoURL = url // I think I want to do something different
                }
            }

        func didRequestClose() {
            parent.onClose()
        }
        }
    
}
