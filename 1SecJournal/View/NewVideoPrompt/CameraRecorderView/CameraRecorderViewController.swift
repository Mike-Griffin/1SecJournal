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
    func didRequestClose()
}

enum CameraError: Error {
    case permissionDenied
    case cameraUnavailable
    case outputUnavailable
    case failedToStart
    case timedOut
    case interrupted
    case runtime(String)

    var message: String {
        switch self {
        case .permissionDenied: return "Camera access is off. Enable it in Settings."
        case .cameraUnavailable: return "No camera is available on this device."
        case .outputUnavailable: return "The camera couldn't be set up for recording."
        case .failedToStart: return "Couldn't start the camera."
        case .timedOut: return "The camera is taking too long to start."
        case .interrupted: return "The camera was interrupted."
        case .runtime(let description): return "Camera error: \(description)"
        }
    }
}

class CameraRecorderViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {
    var captureSession = AVCaptureSession()
    var videoOutput = AVCaptureMovieFileOutput()
    weak var delegate: CustomCameraViewControllerDelegate?
    var previewLayer: AVCaptureVideoPreviewLayer!
    var maxDuration: TimeInterval = 1
    var url: URL?

    let previewContainer = UIView()

    let spinner = UIActivityIndicatorView(style: .large)
    // Lives outside the SwiftUI overlay so it's available while loading and after a failure
    let closeButton = UIButton(type: .system)
    private var toastHostingController: UIHostingController<ToastView>?

    // All capture session work happens on this queue, per Apple's guidance
    private let sessionQueue = DispatchQueue(label: "com.comedichoney.1SecJournal.cameraSession")
    private static let startTimeout: TimeInterval = 3

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSpinner()
        setupCloseButton()
        observeSessionNotifications()
        startWatchdog()
        checkAuthorizationAndStart()
    }

    private func setupSpinner() {
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        spinner.startAnimating()
    }

    private func setupCloseButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        closeButton.setImage(UIImage(systemName: "x.circle", withConfiguration: config), for: .normal)
        closeButton.tintColor = .white
        closeButton.accessibilityLabel = "Close"
        closeButton.addTarget(self, action: #selector(handleCloseTap), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        // Lines up with the header row of CameraRecorderOverlayView
        NSLayoutConstraint.activate([
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            closeButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            closeButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 22)
        ])
    }

    @objc private func handleCloseTap() {
        sessionQueue.async { [captureSession] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
        delegate?.didRequestClose()
    }

    // MARK: Session setup

    private func checkAuthorizationAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { [weak self] in
                self?.configureAndStartSession()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else {
                    DispatchQueue.main.async { self?.showError(.permissionDenied) }
                    return
                }
                self?.sessionQueue.async { self?.configureAndStartSession() }
            }
        default:
            showError(.permissionDenied)
        }
    }

    private func configureAndStartSession() {
        AppLogger.log("👀 configureAndStartSession is beginning \(Date())", level: .verbose)
        if let error = configureSession() {
            DispatchQueue.main.async { [weak self] in
                self?.showError(error)
            }
            return
        }

        let start = Date()
        captureSession.startRunning()
        AppLogger.log("⏳ captureSession startRunning took \(Date().timeIntervalSince(start))", level: .verbose)

        let isRunning = captureSession.isRunning
        DispatchQueue.main.async { [weak self] in
            if isRunning {
                self?.showPreview()
            } else {
                self?.showError(.failedToStart)
            }
        }
    }

    /// Returns nil on success
    private func configureSession() -> CameraError? {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        captureSession.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            AppLogger.log("❌ Cannot add camera input", level: .error)
            return .cameraUnavailable
        }
        captureSession.addInput(input)

        // A video without audio is still worth recording, so a missing microphone isn't an error
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        }

        guard captureSession.canAddOutput(videoOutput) else {
            AppLogger.log("❌ Cannot add video output", level: .error)
            return .outputUnavailable
        }
        captureSession.addOutput(videoOutput)
        videoOutput.maxRecordedDuration = CMTimeMakeWithSeconds(1, preferredTimescale: 600)
        videoOutput.minFreeDiskSpaceLimit = 1024 * 1024
        return nil
    }

    private func startWatchdog() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.startTimeout) { [weak self] in
            guard let self, self.previewLayer == nil, self.toastHostingController == nil else { return }
            self.showError(.timedOut)
        }
    }

    // MARK: Session notifications

    private func observeSessionNotifications() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(sessionRuntimeError(_:)),
                           name: .AVCaptureSessionRuntimeError, object: captureSession)
        center.addObserver(self, selector: #selector(sessionWasInterrupted(_:)),
                           name: .AVCaptureSessionWasInterrupted, object: captureSession)
        center.addObserver(self, selector: #selector(sessionInterruptionEnded(_:)),
                           name: .AVCaptureSessionInterruptionEnded, object: captureSession)
    }

    @objc private func sessionRuntimeError(_ notification: Notification) {
        let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
        AppLogger.log("❌ Capture session runtime error: \(String(describing: error))", level: .error)
        DispatchQueue.main.async { [weak self] in
            self?.showError(.runtime(error?.localizedDescription ?? "Unknown error"))
        }
    }

    @objc private func sessionWasInterrupted(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.showError(.interrupted)
        }
    }

    @objc private func sessionInterruptionEnded(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.hideToast()
        }
    }

    // MARK: UI state

    private func showPreview() {
        spinner.stopAnimating()
        spinner.removeFromSuperview()
        // Clears a timeout toast if the camera started late
        hideToast()
        layoutOverlay()
    }

    private func showError(_ error: CameraError) {
        AppLogger.log("Showing camera error: \(error.message)", level: .error)
        spinner.stopAnimating()
        spinner.removeFromSuperview()
        showToast(error.message)
    }

    private func showToast(_ message: String) {
        hideToast()
        let hostingController = UIHostingController(rootView: ToastView(message: message))
        hostingController.sizingOptions = .intrinsicContentSize
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hostingController)
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hostingController.view.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            hostingController.view.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            hostingController.view.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 12)
        ])
        hostingController.didMove(toParent: self)
        toastHostingController = hostingController
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func hideToast() {
        guard let hostingController = toastHostingController else { return }
        hostingController.willMove(toParent: nil)
        hostingController.view.removeFromSuperview()
        hostingController.removeFromParent()
        toastHostingController = nil
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

        view.bringSubviewToFront(closeButton)
        if let toastView = toastHostingController?.view {
            view.bringSubviewToFront(toastView)
        }
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

    // The file isn't finished until fileOutput(_:didFinishRecordingTo:) is called
    private func stopRecording() {
        videoOutput.stopRecording()
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        // Hitting maxRecordedDuration reports an error even though the file is complete
        if let error = error as NSError?,
           error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool != true {
            AppLogger.log("❌ Recording failed: \(error)", level: .error)
            DispatchQueue.main.async { [weak self] in
                self?.showError(.runtime(error.localizedDescription))
            }
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didFinishRecording(to: outputFileURL)
            self?.dismiss(animated: true)
        }
    }
}
