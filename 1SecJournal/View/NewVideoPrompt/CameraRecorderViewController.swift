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
    var maxDuration: TimeInterval = 10
    var url: URL?
    var recordToggleButton: UIButton?

    let previewContainer = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    func setupCamera() {
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

         // Add output (after input!)
         if captureSession.canAddOutput(videoOutput) {
             captureSession.addOutput(videoOutput)
             videoOutput.maxRecordedDuration = CMTimeMakeWithSeconds(maxDuration, preferredTimescale: 30)
         } else {
             print("❌ Cannot add video output")
         }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        captureSession.commitConfiguration()
        DispatchQueue.global().async { [weak self] in
            self?.captureSession.startRunning()
        }

        // Add record button
        let recordButton = UIButton(type: .system)
        recordButton.setTitle("Record", for: .normal)
        recordButton.setTitleColor(.white, for: .normal)
        recordButton.backgroundColor = .red
        recordButton.layer.cornerRadius = 30
        recordButton.frame = CGRect(x: (view.bounds.width - 60)/2, y: view.bounds.height - 200, width: 60, height: 60)
        recordButton.addTarget(self, action: #selector(startRecording), for: .touchUpInside)
        view.addSubview(recordButton)
        recordToggleButton = recordButton
    }

    @objc func startRecording() {
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
            videoOutput.stopRecording()
            guard let url = url else {
                return
            }
            delegate?.didFinishRecording(to: url)
            return
        }
        
        recordToggleButton?.setTitle("Stop", for: .normal)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("output.mov")
        try? FileManager.default.removeItem(at: tempURL)
        videoOutput.startRecording(to: tempURL, recordingDelegate: self)
        url = tempURL
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        delegate?.didFinishRecording(to: outputFileURL)
        dismiss(animated: true)
    }
}

