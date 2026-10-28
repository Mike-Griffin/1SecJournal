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
            let (cgImage, _) = try await imageGenerator.image(at: time)
            return UIImage(cgImage: cgImage)
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
    
    /// Builds the stitched video in the temporary directory. `progress` is called
    /// from a background thread with values from 0 to 1.
    static func combineVideos(
        clips: [StitchClip],
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let mixComposition = AVMutableComposition()
        guard let videoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw StitchError.compositionFailed
        }
        // Added on first use so a stitch of silent clips doesn't get an empty audio track
        var audioTrack: AVMutableCompositionTrack?

        // Each clip's transform applies from its start time
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        var runningDuration: CMTime = .zero
        var renderSize: CGSize?
        var segments: [Segment] = []

        // Month/Year label
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.setLocalizedDateFormatFromTemplate("MMM yyyy") // e.g., "Aug 2025"

        // Building the composition is quick next to the export, so it gets the first 10%
        let preparationShare = 0.1

        for (index, clip) in clips.enumerated() {
            try Task.checkCancellation()
            AppLogger.log("Processing stitching video at index \(index)")
            let asset = AVURLAsset(url: clip.url)
            do {
                guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                    AppLogger.log("No video track in \(clip.url.lastPathComponent)", level: .error)
                    continue
                }
                let duration = try await asset.load(.duration)
                let (transform, naturalSize) = try await track.load(.preferredTransform, .naturalSize)
                try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: track, at: runningDuration)
                layerInstruction.setTransform(transform, at: runningDuration)

                if renderSize == nil {
                    let transformed = naturalSize.applying(transform)
                    renderSize = CGSize(width: max(1, abs(transformed.width)),
                                        height: max(1, abs(transformed.height)))
                }

                do {
                    if let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first {
                        if audioTrack == nil {
                            audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                        }
                        // Keep the audio within the clip so it can't spill into the next one
                        let audioRange = try await sourceAudio.load(.timeRange)
                        let range = CMTimeRangeGetIntersection(CMTimeRange(start: .zero, duration: duration), otherRange: audioRange)
                        if !range.isEmpty {
                            try audioTrack?.insertTimeRange(range, of: sourceAudio, at: runningDuration + range.start)
                        }
                    }
                } catch {
                    // The clip still plays, just without sound
                    AppLogger.log("Skipping audio for \(clip.url.lastPathComponent): \(error)", level: .error)
                }

                // Collect overlay timing for this clip
                segments.append(.init(start: CMTimeGetSeconds(runningDuration),
                                      duration: CMTimeGetSeconds(duration),
                                      label: df.string(from: clip.date)))
                runningDuration = runningDuration + duration
            } catch {
                try Task.checkCancellation()
                AppLogger.log("Skipping \(clip.url.lastPathComponent): \(error)", level: .error)
            }
            progress(preparationShare * Double(index + 1) / Double(clips.count))
        }

        guard let renderSize, runningDuration > .zero else {
            throw StitchError.noUsableClips
        }

        let videoComposition = AVMutableVideoComposition()

        // One master instruction spanning full timeline
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRange(start: .zero, duration: runningDuration)
        mainInstruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [mainInstruction]
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

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

            parentLayer.addSublayer(textLayer)
        }

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        // MARK: Export
        guard let exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else {
            throw StitchError.compositionFailed
        }
        exportSession.videoComposition = videoComposition
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")

        let progressMonitor = Task {
            for await state in exportSession.states(updateInterval: 0.1) {
                if case .exporting(let exportProgress) = state {
                    progress(preparationShare + (1 - preparationShare) * exportProgress.fractionCompleted)
                }
            }
        }
        defer { progressMonitor.cancel() }

        do {
            AppLogger.log("Beginning to export video \(Date())")
            try await exportSession.export(to: outputURL, as: .mov)
            AppLogger.log("Exported stitched video to \(outputURL) at \(Date())")
        } catch {
            // Don't leave a partial file behind after a failure or cancel
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
        progress(1)
        return outputURL
    }
}

/// The parts of a daily video the stitcher needs, safe to hand off the main actor
struct StitchClip: Sendable {
    let url: URL
    let date: Date
}

enum StitchError: LocalizedError {
    case noUsableClips
    case compositionFailed

    var errorDescription: String? {
        switch self {
        case .noUsableClips: return "None of the selected videos could be read."
        case .compositionFailed: return "The stitch couldn't be set up."
        }
    }
}
