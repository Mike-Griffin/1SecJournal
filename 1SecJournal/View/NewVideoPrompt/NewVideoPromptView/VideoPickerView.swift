//
//  VideoPickerView.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/30/25.
//
import SwiftUI

struct VideoPickerView: UIViewControllerRepresentable {
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
        let parent: VideoPickerView

        init(_ parent: VideoPickerView) {
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
