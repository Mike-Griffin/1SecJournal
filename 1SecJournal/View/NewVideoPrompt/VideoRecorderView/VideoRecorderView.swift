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
    var maxDuration: TimeInterval = 10

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> CameraRecorderViewController {
        var controller: CameraRecorderViewController
        if let recorderVC = CameraPreloader.shared.consumePreloaded() {
            AppLogger.log("Using preloaded VC")
            controller = recorderVC
//            uiViewController.present(recorderVC, animated: true)
        } else {
            // fallback if not preloaded
            AppLogger.log("Constructing new VC")

            controller = CameraRecorderViewController()
//            uiViewController.present(freshVC, animated: true)
        }
        controller.delegate = context.coordinator
        controller.maxDuration = maxDuration
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
        }
    
}
