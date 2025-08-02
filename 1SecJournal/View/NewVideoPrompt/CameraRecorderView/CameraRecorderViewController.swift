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
//        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            setupCameraSession()
        //}
//        setupCameraSession()
    }
    
    override func viewDidAppear(_ animated: Bool) {
//        DispatchQueue.main.async {
            layoutOverlay()
        //}
    }
    
    override func viewDidLayoutSubviews() {
         // layoutOverlay()
    }
    
    func setupCameraSession() {
        AppLogger.log("👀 setupCameraSession is beginning \(Date())", level: .verbose)
//
//        do {
//            let session = AVAudioSession.sharedInstance()
//            try session.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker])
//            try session.setActive(true)
//        } catch {
//            AppLogger.log("❌ Failed to configure AVAudioSession: \(error)")
//        }
//        captureSession.automaticallyConfiguresApplicationAudioSession = false

        captureSession.beginConfiguration()
        
         captureSession.sessionPreset = .high

         // Add input
         guard let device = AVCaptureDevice.default(for: .video),
               let input = try? AVCaptureDeviceInput(device: device),
               captureSession.canAddInput(input) else {
             AppLogger.log("❌ Cannot add camera input")
             return
         }
         captureSession.addInput(input)
        
        // Testing commenting out audioInput. In attempt to solve the slow load time
        
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        }
        
        AppLogger.log("⏳ captureSession addedInput \(Date())", level: .verbose)


         // Add output (after input!)
         if captureSession.canAddOutput(videoOutput) {
             captureSession.addOutput(videoOutput)
             videoOutput.maxRecordedDuration = CMTimeMakeWithSeconds(1, preferredTimescale: 600)
             videoOutput.minFreeDiskSpaceLimit = 1024 * 1024
         } else {
             AppLogger.log("❌ Cannot add video output")
         }
        
        AppLogger.log("⏳ captureSession addedOutput \(Date())", level: .verbose)

        
        captureSession.commitConfiguration()
        AppLogger.log("⏳ captureSession committedConfiguration \(Date())", level: .verbose)

        DispatchQueue.global().async { [weak self] in
            // Not needed since I do this at the beginning
//            try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .videoRecording)
//            try? AVAudioSession.sharedInstance().setActive(true)

            AppLogger.log("⏳ captureSession startRunning \(Date())", level: .verbose)
            let now = Date()

            self?.captureSession.startRunning()
            AppLogger.log("⏳ captureSession startRunning finished at \(Date()) took this long \(Date().timeIntervalSince(now))")


            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if self?.captureSession.isRunning == true {
                    AppLogger.log("✅ Camera is running \(Date())", level: .verbose)
                    // Here you could hide a loading indicator, show preview, etc.
                } else {
                    AppLogger.log("⌛ Camera not running yet \(Date())", level: .verbose)
                }
            }

        }
    }

    func layoutOverlay() {
        guard previewLayer == nil else { return }
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
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
        AppLogger.log("Inputs: \(captureSession.inputs)", level: .verbose)
        AppLogger.log("Outputs: \(captureSession.outputs)", level: .verbose)
        if let connection = videoOutput.connection(with: .video) {
            AppLogger.log("✅ Video connection exists. Active: \(connection.isActive), Enabled: \(connection.isEnabled)", level: .verbose)
        } else {
            AppLogger.log("❌ No video connection found")
        }
        guard let connection = videoOutput.connection(with: .video), connection.isActive else {
            AppLogger.log("Video connection is not active")
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

