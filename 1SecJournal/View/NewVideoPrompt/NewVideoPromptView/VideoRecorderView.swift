//
//  VideoPickerView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/30/25.
//
import SwiftUI
import AVFoundation

struct VideoRecorderView: UIViewControllerRepresentable {
    @Binding var videoURL: URL?
    var maxDuration: TimeInterval = 10

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> CameraRecorderViewController {
        let controller = CameraRecorderViewController()
        controller.delegate = context.coordinator
        controller.maxDuration = maxDuration
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraRecorderViewController, context: Context) {}

    class Coordinator: NSObject, CustomCameraViewControllerDelegate {
        let parent: VideoRecorderView

        init(parent: VideoRecorderView) {
            self.parent = parent
        }

        func didFinishRecording(to url: URL) {
            withAnimation {
                parent.videoURL = url
            }
        }
    }
}

