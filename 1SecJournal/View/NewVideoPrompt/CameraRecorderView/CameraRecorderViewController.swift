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

enum RecordingState {
    case idle
    /// startRecording was called; the file output hasn't confirmed yet
    case starting
    case recording
    /// stopRecording was called; waiting for the file to finish
    case stopping
    case finished
    /// The capture session is being rebuilt after the camera stopped responding
    case restarting
}

/// Shared with the SwiftUI overlay so the record button shows what the camera is actually doing
@Observable final class RecorderModel {
    var state: RecordingState = .idle
}

enum CameraError: Error {
    case permissionDenied
    case cameraUnavailable
    case outputUnavailable
    case failedToStart
    case timedOut
    case interrupted
    case notReady
    case runtime(String)

    var message: String {
        switch self {
        case .permissionDenied: return "Camera access is off. Enable it in Settings."
        case .cameraUnavailable: return "No camera is available on this device."
        case .outputUnavailable: return "The camera couldn't be set up for recording."
        case .failedToStart: return "Couldn't start the camera."
        case .timedOut: return "The camera is taking too long to start."
        case .interrupted: return "The camera was interrupted."
        case .notReady: return "The camera isn't ready yet. Try again."
        case .runtime(let description): return "Camera error: \(description)"
        }
    }
}

class CameraRecorderViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {
    var captureSession = AVCaptureSession()
    var videoOutput = AVCaptureMovieFileOutput()
    weak var delegate: CustomCameraViewControllerDelegate?
    var previewLayer: AVCaptureVideoPreviewLayer!
    var url: URL?
    let recorder = RecorderModel()
    /// The length of every recording
    static let maxDuration: TimeInterval = 1

    let previewContainer = UIView()

    let spinner = UIActivityIndicatorView(style: .large)
    // Lives outside the SwiftUI overlay so it's available while loading and after a failure
    let closeButton = UIButton(type: .system)
    private var toastHostingController: UIHostingController<ToastView>?

    // All capture session work happens on this queue, per Apple's guidance
    private let sessionQueue = DispatchQueue(label: "com.comedichoney.1SecJournal.cameraSession")
    private static let startTimeout: TimeInterval = 3
    /// How long the file output gets to confirm a start or stop before the session is rebuilt
    private static let responseTimeout: TimeInterval = 1
    /// The newest recorder, so a closing one doesn't change the audio session under it
    private static weak var current: CameraRecorderViewController?
    private var responseCheck: DispatchWorkItem?
    private var tapTime: Date?

    override func viewDidLoad() {
        super.viewDidLoad()
        Self.current = self
        view.backgroundColor = .black
        setupSpinner()
        setupCloseButton()
        observeSessionNotifications()
        startWatchdog()
        checkAuthorizationAndStart()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Recording finished or the screen closed: release the camera and put the
        // audio session back, since capture leaves it set up for recording
        sessionQueue.async { [captureSession] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
            DispatchQueue.main.async { [weak self] in
                guard Self.current == nil || Self.current === self else { return }
                AudioSession.configureForPlayback()
            }
        }
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
        videoOutput.maxRecordedDuration = CMTimeMakeWithSeconds(Self.maxDuration, preferredTimescale: 600)
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


        let overlayView = CameraRecorderOverlayView(recorder: recorder) { [weak self] in
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
        switch recorder.state {
        case .idle:
            startRecording()
        case .starting, .recording:
            // Stops early; a clip that started is still saved
            stopRecording()
        case .stopping, .finished, .restarting:
            break
        }
    }

    private func startRecording() {
        guard let connection = videoOutput.connection(with: .video), connection.isActive else {
            logDiagnostics("Record tapped but the video connection isn't active")
            showToast(CameraError.notReady.message)
            return
        }
        hideToast()
        // A new file each time, so a player still holding the last take can't get in the way
        let directory = FileManager.default.temporaryDirectory.appending(path: "Recordings", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appending(path: UUID().uuidString + ".mov")

        tapTime = Date()
        logDiagnostics("Starting recording")
        recorder.state = .starting
        videoOutput.startRecording(to: fileURL, recordingDelegate: self)
        url = fileURL
        expectResponse(while: .starting, "Recording never started")
    }

    // The file isn't finished until fileOutput(_:didFinishRecordingTo:) is called
    private func stopRecording() {
        logDiagnostics("Stopping recording")
        recorder.state = .stopping
        videoOutput.stopRecording()
        expectResponse(while: .stopping, "Recording never finished after stopping")
    }

    /// Rebuilds the session if the state hasn't moved on in time, since the file output can
    /// get into a state where it ignores both start and stop until it's recreated
    private func expectResponse(while state: RecordingState, _ problem: String, after delay: TimeInterval = responseTimeout) {
        responseCheck?.cancel()
        let check = DispatchWorkItem { [weak self] in
            guard let self, self.recorder.state == state else { return }
            self.restartSession(after: problem)
        }
        responseCheck = check
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: check)
    }

    private func restartSession(after problem: String) {
        logDiagnostics("STUCK: \(problem). Restarting the capture session")
        recorder.state = .restarting
        // Callbacks from the old output are ignored once it's replaced
        videoOutput.stopRecording()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let session = self.captureSession
            session.stopRunning()
            session.beginConfiguration()
            session.inputs.forEach(session.removeInput)
            session.outputs.forEach(session.removeOutput)
            session.commitConfiguration()
            self.videoOutput = AVCaptureMovieFileOutput()
            let error = self.configureSession()
            if error == nil {
                session.startRunning()
            }
            let isRunning = session.isRunning
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let error {
                    self.showError(error)
                } else if !isRunning {
                    self.showError(.failedToStart)
                } else {
                    self.recorder.state = .idle
                    self.logDiagnostics("Capture session restarted")
                    self.showToast("The camera got stuck, so it was restarted. Try again.")
                }
            }
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        DispatchQueue.main.async { [weak self] in
            guard let self, output === self.videoOutput, self.recorder.state == .starting else { return }
            let delay = self.tapTime.map { Date().timeIntervalSince($0) } ?? 0
            self.logDiagnostics("Recording started after \(String(format: "%.2f", delay))s")
            self.recorder.state = .recording
            // maxRecordedDuration should stop it; this makes sure a missed stop can't leave it running
            self.responseCheck?.cancel()
            let backstop = DispatchWorkItem { [weak self] in
                guard let self, self.recorder.state == .recording else { return }
                self.logDiagnostics("Recording didn't stop at its limit")
                self.stopRecording()
            }
            self.responseCheck = backstop
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.maxDuration + 0.5, execute: backstop)
        }
    }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        // Hitting maxRecordedDuration reports an error even though the file is complete
        let nsError = error as NSError?
        let succeeded = nsError == nil || nsError?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true
        DispatchQueue.main.async { [weak self] in
            guard let self, output === self.videoOutput else { return }
            self.responseCheck?.cancel()
            guard succeeded else {
                self.logDiagnostics("Recording failed: \(String(describing: nsError))")
                self.recorder.state = .idle
                self.showError(.runtime(nsError?.localizedDescription ?? "Unknown error"))
                return
            }
            self.logDiagnostics("Recording finished")
            self.recorder.state = .finished
            // SwiftUI swaps this screen for the preview. Don't call dismiss(animated:) here:
            // inside a full-screen cover it closes the whole cover before the clip is saved.
            self.delegate?.didFinishRecording(to: outputFileURL)
            // The preview should replace this screen; if it doesn't, don't leave the button stuck
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, self.recorder.state == .finished, self.viewIfLoaded?.window != nil else { return }
                self.logDiagnostics("STUCK: still on the camera after the recording finished")
                self.recorder.state = .idle
                self.showToast("Couldn't open the recording. Try again.")
            }
        }
    }

    // MARK: Diagnostics

    /// Logged and kept in a file that Export Backup includes, so a recording that gets
    /// stuck on the phone can be looked at afterwards
    private func logDiagnostics(_ event: String) {
        let audioSession = AVAudioSession.sharedInstance()
        let videoConnection = videoOutput.connection(with: .video)
        let audioConnection = videoOutput.connection(with: .audio)
        let details = [
            "state=\(recorder.state)",
            "running=\(captureSession.isRunning)",
            "interrupted=\(captureSession.isInterrupted)",
            "outputRecording=\(videoOutput.isRecording)",
            "video=\(videoConnection.map { "active:\($0.isActive) enabled:\($0.isEnabled)" } ?? "none")",
            "audio=\(audioConnection.map { "active:\($0.isActive) enabled:\($0.isEnabled)" } ?? "none")",
            "audioSession=\(audioSession.category.rawValue)/\(audioSession.mode.rawValue)",
            "otherAudio=\(audioSession.isOtherAudioPlaying)",
        ].joined(separator: " ")
        AppLogger.log("🎥 \(event) | \(details)")
        RecorderDiagnostics.append("\(Date().ISO8601Format()) \(event) | \(details)")
    }
}

enum RecorderDiagnostics {
    private static let queue = DispatchQueue(label: "com.comedichoney.1SecJournal.recorderDiagnostics")
    private static let maxSize = 256 * 1024

    static func append(_ line: String) {
        queue.async {
            guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup)?
                .appending(path: "Recorder Diagnostics.log") else { return }
            var text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            text += line + "\n"
            // Keeps the newest half once the file gets big
            if text.utf8.count > maxSize {
                text = String(text.suffix(text.count / 2))
            }
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
