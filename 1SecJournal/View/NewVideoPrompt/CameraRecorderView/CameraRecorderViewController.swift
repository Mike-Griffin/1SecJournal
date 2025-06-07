//
//  CameraRecorderViewController.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/30/25.
//

import SwiftUI
import AVKit

protocol CustomCameraViewControllerDelegate: AnyObject {
    func didFinishRecording(to url: URL)
}

class CameraRecorderViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {
    var captureSession = AVCaptureSession()
    var videoOutput = AVCaptureMovieFileOutput()
    weak var delegate: CustomCameraViewControllerDelegate?
    var previewLayer: AVCaptureVideoPreviewLayer!
    var maxDuration: TimeInterval = 1
    var url: URL?

    let previewContainer = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCameraSession()
    }
    
    override func viewDidLayoutSubviews() {
         layoutOverlay()
    }
    
    func setupCameraSession() {
        captureSession.beginConfiguration()
         captureSession.sessionPreset = .high

         // Add input
         guard let device = AVCaptureDevice.default(for: .video),
               let input = try? AVCaptureDeviceInput(device: device),
               captureSession.canAddInput(input) else {
             print("❌ Cannot add camera input")
             return
         }
         captureSession.addInput(input)
        
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        }

         // Add output (after input!)
         if captureSession.canAddOutput(videoOutput) {
             captureSession.addOutput(videoOutput)
             videoOutput.maxRecordedDuration = CMTimeMakeWithSeconds(1, preferredTimescale: 600)
             videoOutput.minFreeDiskSpaceLimit = 1024 * 1024
         } else {
             print("❌ Cannot add video output")
         }
        
        captureSession.commitConfiguration()
        DispatchQueue.global().async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func layoutOverlay() {
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.frame
        view.layer.addSublayer(previewLayer)


        let overlayView = CameraRecorderOverlayView { [weak self] in
            self?.handleRecordButtonTap()
        }
        let hostingController = UIHostingController(rootView: overlayView)
        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.backgroundColor = .clear
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }

    @objc func handleRecordButtonTap() {
        print("Inputs: \(captureSession.inputs)")
        print("Outputs: \(captureSession.outputs)")
        if let connection = videoOutput.connection(with: .video) {
            print("✅ Video connection exists. Active: \(connection.isActive), Enabled: \(connection.isEnabled)")
        } else {
            print("❌ No video connection found")
        }
        guard let connection = videoOutput.connection(with: .video), connection.isActive else {
            print("Video connection is not active")
            return
        }
        guard !videoOutput.isRecording else {
            stopRecording()
            return
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("output.mov")
        try? FileManager.default.removeItem(at: tempURL)
        videoOutput.startRecording(to: tempURL, recordingDelegate: self)
        url = tempURL
    }
    
    private func stopRecording() {
        videoOutput.stopRecording()
        guard let url = url else {
            return
        }
        delegate?.didFinishRecording(to: url)
        return
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        delegate?.didFinishRecording(to: outputFileURL)
        dismiss(animated: true)
    }
}

