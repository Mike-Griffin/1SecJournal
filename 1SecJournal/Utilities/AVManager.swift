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
    
    static private func makeDateLayer(
        text: String,
        renderSize: CGSize,
        inset: CGFloat = 24,
        fontSize: CGFloat = 40,
        font: UIFont = .systemFont(ofSize: 40, weight: .semibold),
        textColor: UIColor = .white,
        screenScale: CGFloat = 2.0
    ) -> CALayer {
        let bgColor = UIColor.black.withAlphaComponent(0.35)
        let scale = max(screenScale, 2.0) // crisp on export

        let attr = NSAttributedString(
            string: text,
            attributes: [
            .font: font,
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.white,
            .strokeWidth: -1.0
            ]
        )

        let bounds = attr.boundingRect(
            with: CGSize(width: Swift.Double.greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).integral
        
        // Padding for pill background
        let bgPadX: CGFloat = max(12, fontSize * 0.35)
        let bgPadY: CGFloat = max(8,  fontSize * 0.20)
        
        // --- compute pill size ---
        let pillWidth  = bounds.width  + bgPadX * 2
        let pillHeight = bounds.height + bgPadY * 2

        // --- safe-area centering (adds margin from edges) ---
//        let safeWidth  = max(0, renderSize.width  - inset*2)
//        let safeHeight = max(0, renderSize.height - inset*2)
        
        let bgLayer = CALayer()
        bgLayer.backgroundColor = bgColor.cgColor
        bgLayer.cornerRadius = 8
        bgLayer.masksToBounds = true
        let bgFrame = CGRect(
            // This works but it goes directly to the edge
//            x: (renderSize.width  - (bounds.width + bgPadX*2)) / 2,
//            y: (renderSize.height - (bounds.height + bgPadY*2)) / 2,
            x: renderSize.width - inset - pillWidth,
            y: renderSize.height - inset - pillHeight,
            width:  pillWidth,
            height: pillHeight
        ).integral
        bgLayer.frame = bgFrame
        
        // Text layer
        let textLayer = CATextLayer()
        textLayer.contentsScale = scale
        textLayer.rasterizationScale = scale
        textLayer.alignmentMode = .center
        textLayer.string = attr
        textLayer.frame = bgFrame.insetBy(dx: bgPadX, dy: bgPadY).integral
        textLayer.shadowColor = UIColor.black.cgColor
        textLayer.shadowOpacity = 0.75
        textLayer.shadowRadius = 3
        textLayer.shadowOffset = CGSize(width: 0, height: 1)


        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: renderSize)
        container.addSublayer(bgLayer)
        container.addSublayer(textLayer)
        AppLogger.log("Returning Container for \(text) with frame: \(container.frame)")
        return container
    }

    private struct Segment {
        var start: Double   // seconds from start of stitched video
        var duration: Double
        var label: String   // e.g. "Aug 2025"
    }
    
    static func combineVideos(videos: [DailyVideoEntry]) async -> URL? {
        let mixComposition = AVMutableComposition()
        guard let videoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            reportIssue("Error creating video track")
            return nil
        }

        
        var runningDuration: CMTime = .zero
//        var instructions: [AVMutableVideoCompositionInstruction] = []
        
        // Preload all assets and tracks
        var firstTransform: CGAffineTransform? = nil
        var firstNaturalSize: CGSize? = nil
        
        var segments: [Segment] = []

        // Month/Year label
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.setLocalizedDateFormatFromTemplate("MMM yyyy") // e.g., "Aug 2025"
        
        for (index, video) in videos.enumerated() {
            AppLogger.log("Processing stitching video at index \(index)")
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
                    
                    let transform = try await track.load(.preferredTransform)
                    
                    if index == 0 {
                        // Preload all assets and tracks
                        firstTransform = transform
                        firstNaturalSize = try await track.load(.naturalSize)
                    }
                    
                    // Collect overlay timing for this clip
                    let startSec = CMTimeGetSeconds(runningDuration)
                    let durSec = CMTimeGetSeconds(duration)
                    segments.append(.init(start: startSec, duration: durSec, label: df.string(from: video.date)))
                    
                    runningDuration = CMTimeAdd(runningDuration, duration)
                } catch {
                    AppLogger.log(error.localizedDescription)
                    continue
                }
            }
        let videoComposition = AVMutableVideoComposition()
        
        // One master instruction spanning full timeline
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRange(start: .zero, duration: runningDuration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)

        // Apply each segment’s transform at its start time
        var cursor: CMTime = .zero
        for video in videos {
            let asset = AVURLAsset(url: video.fileURL)
            if let vt = try? await asset.loadTracks(withMediaType: .video).first,
               let t = try? await vt.load(.preferredTransform),
               let d = try? await asset.load(.duration) {
                layerInstruction.setTransform(t, at: cursor)
                cursor = cursor + d
            }
        }
        mainInstruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [mainInstruction]
        
        // Coalesce adjacent segments that share the same label
        var coalesced: [Segment] = []
        for seg in segments {
            if var last = coalesced.last, last.label == seg.label,
               abs((last.start + last.duration) - seg.start) < 0.001 {
                last.duration += seg.duration
                coalesced.removeLast()
                coalesced.append(last)
            } else {
                coalesced.append(seg)
            }
        }
        
        // Use the render size from the first track (or max size if clips vary)
        guard let baseSize = firstNaturalSize,
              let baseTransform = firstTransform else {
            reportIssue("Failed to determine render size")
            return nil
        }
        let transformed = baseSize.applying(baseTransform)
        let renderSize = CGSize(width: max(1, abs(transformed.width)),
                                height: max(1, abs(transformed.height)))
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        // Build overlay layer tree
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = parentLayer.frame
        parentLayer.addSublayer(videoLayer)
        
        parentLayer.beginTime = AVCoreAnimationBeginTimeAtZero
        parentLayer.isGeometryFlipped = true

        for seg in coalesced {
            // Caller should pass the correct scale from view/window context
            let textLayer = makeDateLayer(text: seg.label, renderSize: renderSize, screenScale: 2.0)

            // Show only during this segment
            textLayer.beginTime = seg.start
            textLayer.duration  = seg.duration

            // Optional: quick fade in/out so label changes are less abrupt
            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0
            fadeIn.toValue = 1
            fadeIn.beginTime = seg.start
            fadeIn.duration = 0.15
            fadeIn.fillMode = .both
            fadeIn.isRemovedOnCompletion = false
//            textLayer.add(fadeIn, forKey: "fadeIn")

            let fadeOut = CABasicAnimation(keyPath: "opacity")
            fadeOut.fromValue = 1
            fadeOut.toValue = 0
            fadeOut.beginTime = seg.start + max(0, seg.duration - 0.2)
            fadeOut.duration = 0.15
            fadeOut.fillMode = .both
            fadeOut.isRemovedOnCompletion = false
//            textLayer.add(fadeOut, forKey: "fadeOut")

            parentLayer.addSublayer(textLayer)
            parentLayer.backgroundColor = UIColor.green.withAlphaComponent(0.1).cgColor

        }

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
        

            
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
            AppLogger.log("Exported stitched video to \(outputURL)")
            return outputURL
        } catch {
            reportIssue(error)
        }
        reportIssue("returning nil")
        return nil
    }
}

