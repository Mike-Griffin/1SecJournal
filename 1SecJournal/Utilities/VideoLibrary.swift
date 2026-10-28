//
//  VideoLibrary.swift
//  1SecJournal
//
//  Created by Mike Griffin on 10/27/26.
//
import SwiftData
import Foundation

/// Lookups between stitches and their source videos, and deletes that clean up files.
/// Stitches refer to sources by ID (see StitchedVideoEntry.sourceVideoIDs).
@MainActor
enum VideoLibrary {
    /// The stitch's sources that still exist, oldest first
    static func sources(of stitch: StitchedVideoEntry, in context: ModelContext) throws -> [DailyVideoEntry] {
        guard !stitch.sourceVideoIDs.isEmpty else { return [] }
        let dailyById = try dailyVideosById(in: context)
        return stitch.sourceVideoIDs.compactMap { dailyById[$0] }
    }

    /// Newest first
    static func stitches(containing video: DailyVideoEntry, in context: ModelContext) throws -> [StitchedVideoEntry] {
        let descriptor = FetchDescriptor<StitchedVideoEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return try context.fetch(descriptor).filter { $0.sourceVideoIDs.contains(video.id) }
    }

    /// Deletes the entry and then its video and thumbnail files. Deleting a daily video
    /// removes it from the stitches it's in; their own videos aren't touched. Deleting a
    /// stitch never deletes its source videos.
    static func delete(_ video: VideoEntry, in context: ModelContext) throws {
        let filenames = [video.filename, video.thumbnailFilename]
        if let dailyVideo = video as? DailyVideoEntry {
            for stitch in try stitches(containing: dailyVideo, in: context) {
                stitch.sourceVideoIDs.removeAll { $0 == dailyVideo.id }
            }
        }
        context.delete(video)
        try context.save()
        // Only once the entry is gone, so a failed save never leaves an entry without its files
        for filename in filenames {
            removeFile(named: filename)
        }
    }

    private static func dailyVideosById(in context: ModelContext) throws -> [UUID: DailyVideoEntry] {
        let dailyVideos = try context.fetch(FetchDescriptor<DailyVideoEntry>())
        return Dictionary(dailyVideos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Removes a file stored directly in the app group container. Refuses anything else,
    /// since an empty filename would otherwise point at the container itself.
    private static func removeFile(named filename: String) {
        guard !filename.isEmpty, !filename.contains("/"), filename != ".", filename != "..",
              let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup) else {
            return
        }
        let url = containerURL.appending(path: filename)
        do {
            try FileManager.default.removeItem(at: url)
        } catch CocoaError.fileNoSuchFile {
            // Already gone
        } catch {
            AppLogger.log("Failed to remove \(filename): \(error)", level: .error)
        }
    }
}
