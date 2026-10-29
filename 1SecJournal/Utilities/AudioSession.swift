//
//  AudioSession.swift
//  1SecJournal
//
//  Created by Mike Griffin on 10/28/26.
//
import AVFoundation

enum AudioSession {
    /// Videos play with sound even when the Silent switch is on, like Photos. Without this
    /// the app uses the default category, which is muted on silent until the camera
    /// switches it to recording. Other apps' audio pauses while a video plays.
    static func configureForPlayback() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            AppLogger.log("Failed to set the audio session category: \(error)", level: .error)
        }
    }
}
