//
//  CameraPreloader.swift
//  1SecJournal
//
//  Created by Mike Griffin on 7/30/25.
//

class CameraPreloader {
    static let shared = CameraPreloader()

    private(set) var recorderVC: CameraRecorderViewController?

    func preload() {
        guard recorderVC == nil else { return }

        let vc = CameraRecorderViewController()
        vc.loadViewIfNeeded() // Ensures viewDidLoad gets called
        recorderVC = vc
    }

    func consumePreloaded() -> CameraRecorderViewController? {
        defer { recorderVC = nil }
        return recorderVC
    }
}
