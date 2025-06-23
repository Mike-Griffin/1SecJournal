//
//  AVManager.swift
//  1SecJournal
//
//  Created by Mike Griffin on 6/22/25.
//
import UIKit
import IssueReporting
import AVFoundation


struct AVManager {
    
    static func getThumbnail(from videoURL: URL) async -> UIImage? {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1, preferredTimescale: 600) // 1 second into video
        do {
            // It's possible I'm not throwing the error properly, but I think it should be
            return try await withCheckedThrowingContinuation { continuation in
                imageGenerator.generateCGImageAsynchronously(for: time) { cgImage,_,_  in         if let cgImage = cgImage {
                    continuation.resume(returning: UIImage(cgImage: cgImage))
                }
                }
            }
        } catch {
            reportIssue("Failed to generate thumbnail: \(error)")
            return nil
        }
        
    }
    
    static func combineVideos(videos: [DailyVideoEntry]) async -> URL? {
        let mixComposition = AVMutableComposition()
        guard let videoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            reportIssue("Error creating video track")
            return nil
        }

        
        var runningDuration: CMTime = .zero
        var instructions: [AVMutableVideoCompositionInstruction] = []
        
        // Preload all assets and tracks
        var firstTransform: CGAffineTransform? = nil
        var firstNaturalSize: CGSize? = nil
        
        for (index, video) in videos.enumerated() {
                let videoURL = video.fileURL
                let asset = AVURLAsset(url: videoURL)
                do {
                    guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                        reportIssue("no video track found")
                        continue
                    }
                    let duration = try await asset.load(.duration)
                    let timeRange = CMTimeRange(start: .zero, duration: duration)
                    try videoTrack.insertTimeRange(timeRange, of: track, at: runningDuration)
                    
                    let instruction = AVMutableVideoCompositionInstruction()
                    instruction.timeRange = CMTimeRange(start: runningDuration, duration: duration)

                    let transform = try await track.load(.preferredTransform)
                    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                    layerInstruction.setTransform(transform, at: runningDuration)

                    instruction.layerInstructions = [layerInstruction]
                    instructions.append(instruction)
                    
                    if index == 0 {
                        // Preload all assets and tracks
                        firstTransform = transform
                        firstNaturalSize = try await track.load(.naturalSize)
                    }
                    
                    runningDuration = CMTimeAdd(runningDuration, duration)
                } catch {
                    print(error.localizedDescription)
                    continue
                }
            }
        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = instructions
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        // Use the render size from the first track (or max size if clips vary)
        guard let renderSize = firstNaturalSize?.applying(firstTransform ?? .identity) else {
            reportIssue("Failed to determine render size")
            return nil
        }
        videoComposition.renderSize = CGSize(width: abs(renderSize.width), height: abs(renderSize.height))
            
            // MARK: Export
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
            
            guard let exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else {
                reportIssue("Failed to create export session")
                return nil
            }
            
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mov
            exportSession.videoComposition = videoComposition
        do {
            try await exportSession.export(to: outputURL, as: .mov)
            return outputURL
        } catch {
            reportIssue(error)
        }
        reportIssue("returning nil")
        return nil
    }
}
