//
//  BackupExporter.swift
//  1SecJournal
//
//  Created by Mike Griffin on 10/27/26.
//
import Foundation

/// Zips everything the app stores (videos, thumbnails, and the SwiftData store,
/// which all live in the app group container) so it can be saved off the phone
enum BackupExporter {
    enum BackupError: LocalizedError {
        case containerUnavailable
        case storeMissing
        case zipFailed

        var errorDescription: String? {
            switch self {
            case .containerUnavailable: return "The app's storage couldn't be found."
            case .storeMissing: return "The database wasn't found, so the backup would be incomplete."
            case .zipFailed: return "The backup couldn't be compressed."
            }
        }
    }

    private static let namePrefix = "1SecJournal Backup"

    /// Returns the zip's URL in the temporary directory. Save the model context first
    /// so the store on disk is current.
    static func makeBackup() async throws -> URL {
        let fileManager = FileManager.default
        guard let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup) else {
            throw BackupError.containerUnavailable
        }
        let temporaryDirectory = fileManager.temporaryDirectory
        removeOldBackups(in: temporaryDirectory)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        let name = "\(namePrefix) \(formatter.string(from: Date()))"

        let staging = temporaryDirectory.appending(path: name, directoryHint: .isDirectory)
        try? fileManager.removeItem(at: staging)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }

        // Copies on the same volume are clones, so staging doesn't double the space used
        let topLevelItems = try fileManager.contentsOfDirectory(at: container,
                                                                includingPropertiesForKeys: nil,
                                                                options: [.skipsHiddenFiles])
        for item in topLevelItems where item.lastPathComponent != "Library" {
            try fileManager.copyItem(at: item, to: staging.appending(path: item.lastPathComponent))
        }
        // From Library, only Application Support (where the store lives) matters; Caches can be rebuilt
        let applicationSupport = container.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        // path() would percent-encode the space in "Application Support", so use the plain path
        guard fileManager.fileExists(atPath: applicationSupport.appending(path: "default.store").path(percentEncoded: false)) else {
            throw BackupError.storeMissing
        }
        let library = staging.appending(path: "Library", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: library, withIntermediateDirectories: true)
        try fileManager.copyItem(at: applicationSupport, to: library.appending(path: "Application Support"))

        try readme(for: staging).write(to: staging.appending(path: "README.txt"), atomically: true, encoding: .utf8)
        return try zip(staging, to: temporaryDirectory.appending(path: "\(name).zip"))
    }

    private static func zip(_ directory: URL, to destination: URL) throws -> URL {
        try? FileManager.default.removeItem(at: destination)
        var coordinatorError: NSError?
        var copyError: Error?
        // Reading a directory "for uploading" hands back a zipped copy of it
        NSFileCoordinator().coordinate(readingItemAt: directory, options: .forUploading, error: &coordinatorError) { zipURL in
            do {
                // zipURL is only valid inside this block
                try FileManager.default.copyItem(at: zipURL, to: destination)
            } catch {
                copyError = error
            }
        }
        if let error = coordinatorError ?? copyError {
            AppLogger.log("Backup zip failed: \(error)", level: .error)
            throw BackupError.zipFailed
        }
        return destination
    }

    private static func readme(for directory: URL) -> String {
        var videoCount = 0
        var totalBytes: Int64 = 0
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey])
        while let file = enumerator?.nextObject() as? URL {
            if file.pathExtension == "mov" { videoCount += 1 }
            totalBytes += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return """
        1SecJournal backup
        Created: \(Date().formatted(date: .complete, time: .standard))
        App version: \(version) (\(build))
        Videos (.mov): \(videoCount)
        Size: \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))

        This is the contents of the app group container \(kAppGroup).
        Library/Application Support/default.store (with -wal and -shm) is the SwiftData store.
        The .mov and .jpg files are the videos and thumbnails it refers to by filename.
        """
    }

    /// Earlier backups are only needed until they've been shared
    private static func removeOldBackups(in directory: URL) {
        let items = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for item in items where item.lastPathComponent.hasPrefix(namePrefix) {
            try? FileManager.default.removeItem(at: item)
        }
    }
}
