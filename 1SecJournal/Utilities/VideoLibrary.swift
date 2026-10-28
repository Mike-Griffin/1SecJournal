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

    // MARK: - Unlinked files

    /// Video and thumbnail files that no entry refers to, e.g. from a save that didn't
    /// finish. A video "X.mov" and its thumbnail "Xthumb.jpg" are grouped together.
    struct UnlinkedVideo: Identifiable, Hashable {
        let id: String
        var videoFilename: String?
        var thumbnailFilename: String?
    }

    enum RestoreKind {
        case daily
        case stitch
    }

    static func unlinkedFiles(in context: ModelContext) throws -> [UnlinkedVideo] {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup) else {
            return []
        }
        let entries = try context.fetch(FetchDescriptor<VideoEntry>())
        let referenced = Set(entries.flatMap { [$0.filename, $0.thumbnailFilename] })
        let filenames = try FileManager.default.contentsOfDirectory(atPath: containerURL.path(percentEncoded: false))

        var byKey: [String: UnlinkedVideo] = [:]
        for filename in filenames where !referenced.contains(filename) {
            if filename.hasSuffix(".mov") {
                let key = String(filename.dropLast(".mov".count))
                byKey[key, default: UnlinkedVideo(id: key)].videoFilename = filename
            } else if filename.hasSuffix("thumb.jpg") {
                let key = String(filename.dropLast("thumb.jpg".count))
                byKey[key, default: UnlinkedVideo(id: key)].thumbnailFilename = filename
            }
        }
        return Array(byKey.values)
    }

    /// Adds an entry for an unlinked video, making a thumbnail if it doesn't have one.
    /// A restored stitch isn't linked to any daily videos.
    @discardableResult
    static func restore(_ unlinked: UnlinkedVideo, as kind: RestoreKind, date: Date, in context: ModelContext) async throws -> VideoEntry {
        guard let videoFilename = unlinked.videoFilename,
              let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup) else {
            throw CocoaError(.fileNoSuchFile)
        }
        var thumbnailFilename = unlinked.thumbnailFilename
        if thumbnailFilename == nil {
            guard let image = await AVManager.getThumbnail(from: containerURL.appending(path: videoFilename)),
                  let data = image.jpegData(compressionQuality: 0.8) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let filename = unlinked.id + "thumb.jpg"
            try data.write(to: containerURL.appending(path: filename), options: .atomic)
            thumbnailFilename = filename
        }

        let entry: VideoEntry
        switch kind {
        case .daily:
            entry = DailyVideoEntry(filename: videoFilename, thumbnailFilename: thumbnailFilename ?? "")
        case .stitch:
            entry = StitchedVideoEntry(filename: videoFilename, thumbnailFilename: thumbnailFilename ?? "", composingVideos: [])
        }
        entry.date = date
        context.insert(entry)
        do {
            try context.save()
        } catch {
            context.delete(entry)
            throw error
        }
        return entry
    }

    static func removeFiles(of unlinked: UnlinkedVideo) {
        for filename in [unlinked.videoFilename, unlinked.thumbnailFilename].compactMap({ $0 }) {
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
