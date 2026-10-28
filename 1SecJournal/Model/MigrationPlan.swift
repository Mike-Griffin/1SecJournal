//
//  MigrationPlan.swift
//  1SecJournal
//
//  Created by Mike Griffin on 10/27/26.
//
import SwiftData
import CoreData
import Foundation

/// The current models: title, journal text, and updatedAt on every video, and on
/// stitches the IDs of their source videos (any number of stitches per video) and a saved date range
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [VideoEntry.self, DailyVideoEntry.self, StitchedVideoEntry.self]
    }
}

enum VideoMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// V1 stored each daily video's stitch as a single relationship column, which V2
    /// replaces with sourceVideoIDs on the stitch, so the links are saved before migrating
    /// and written back once the container is open (see AppModelContainer.make)
    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: { context in
            let stitches = try context.fetch(FetchDescriptor<SchemaV1.StitchedVideoEntry>())
            let links = stitches.map { stitch in
                let dates = stitch.composingVideos.map(\.date)
                return StitchLinkSnapshot.Link(stitchId: stitch.id,
                                               sourceIds: stitch.composingVideos.map(\.id),
                                               rangeStart: dates.min(),
                                               rangeEnd: dates.max())
            }
            try StitchLinkSnapshot.save(links)
            AppLogger.log("Saved links for \(links.count) stitches before migrating to V2")
        },
        // Written back after the container opens instead, in the app's own context
        didMigrate: nil
    )
}

/// The V1 stitch links, written to disk so they survive even if the migration
/// is interrupted. Applied once, then renamed so it's kept as a record.
enum StitchLinkSnapshot {
    struct Link: Codable {
        let stitchId: UUID
        let sourceIds: [UUID]
        let rangeStart: Date?
        let rangeEnd: Date?
    }

    private static var pendingURL: URL? {
        StoreLocation.applicationSupport?.appending(path: "StitchLinks-V1.json")
    }

    private static var appliedURL: URL? {
        StoreLocation.applicationSupport?.appending(path: "StitchLinks-V1.applied.json")
    }

    static var isPending: Bool {
        guard let pendingURL else { return false }
        return FileManager.default.fileExists(atPath: pendingURL.path(percentEncoded: false))
    }

    static func save(_ links: [Link]) throws {
        guard let pendingURL else { throw StoreLocation.LocationError.containerUnavailable }
        let data = try JSONEncoder().encode(links)
        try data.write(to: pendingURL, options: .atomic)
    }

    /// Gives each stitch its source video IDs and date range
    static func apply(in context: ModelContext) throws {
        guard isPending, let pendingURL, let appliedURL else { return }
        let links = try JSONDecoder().decode([Link].self, from: Data(contentsOf: pendingURL))
        let linksByStitch = Dictionary(links.map { ($0.stitchId, $0) }, uniquingKeysWith: { first, _ in first })

        let dailyVideos = try context.fetch(FetchDescriptor<DailyVideoEntry>())
        let dailyById = Dictionary(dailyVideos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var restoredLinks = 0
        for stitch in try context.fetch(FetchDescriptor<StitchedVideoEntry>()) {
            guard let link = linksByStitch[stitch.id] else { continue }
            let sources = link.sourceIds.compactMap { dailyById[$0] }.sorted { $0.date < $1.date }
            stitch.sourceVideoIDs = sources.map(\.id)
            stitch.rangeStart = link.rangeStart
            stitch.rangeEnd = link.rangeEnd
            restoredLinks += sources.count
        }
        try context.save()

        try? FileManager.default.removeItem(at: appliedURL)
        try FileManager.default.moveItem(at: pendingURL, to: appliedURL)
        AppLogger.log("Restored \(restoredLinks) stitch links across \(links.count) stitches")
    }
}

enum StoreLocation {
    enum LocationError: LocalizedError {
        case containerUnavailable

        var errorDescription: String? { "The app's storage couldn't be found." }
    }

    /// Where SwiftData has always put the store: the app group's Application Support
    static var applicationSupport: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup)?
            .appending(path: "Library/Application Support", directoryHint: .isDirectory)
    }

    static var storeURL: URL? {
        applicationSupport?.appending(path: "default.store")
    }
}

enum AppModelContainer {

    /// Never deletes or replaces the store. If it can't be opened, the error is
    /// returned so the app can explain instead of crashing or starting fresh.
    @MainActor
    static func make() -> Result<ModelContainer, Error> {
        do {
            guard let storeURL = StoreLocation.storeURL else {
                throw StoreLocation.LocationError.containerUnavailable
            }
            try copyStoreBeforeMigrationIfNeeded(storeURL: storeURL)
            // On a fresh install the folder doesn't exist yet, and Core Data logs a wall of errors creating it
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            let schema = Schema(versionedSchema: SchemaV2.self)
            let configuration = ModelConfiguration(schema: schema, url: storeURL)
            let container = try ModelContainer(for: schema,
                                               migrationPlan: VideoMigrationPlan.self,
                                               configurations: configuration)

            // Also picks up links saved by a migration that was interrupted
            if StitchLinkSnapshot.isPending {
                try StitchLinkSnapshot.apply(in: container.mainContext)
            }
            return .success(container)
        } catch {
            AppLogger.log("Failed to open the store: \(error)", level: .error)
            return .failure(error)
        }
    }

    /// Copies the store files aside before they're first opened with a newer schema.
    /// Decided from the version the store records about itself, which reading doesn't change.
    private static func copyStoreBeforeMigrationIfNeeded(storeURL: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: storeURL.path(percentEncoded: false)) else { return }
        let currentVersion = SchemaV2.versionIdentifier.description
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: storeURL)
        let storeVersions = metadata["NSStoreModelVersionIdentifiers"] as? [String] ?? []
        guard !storeVersions.contains(currentVersion) else { return }

        let backupFolder = storeURL.deletingLastPathComponent()
            .appending(path: "Pre-\(currentVersion) Store Backup", directoryHint: .isDirectory)
        // Keep the first copy if an earlier attempt already made one
        guard !fileManager.fileExists(atPath: backupFolder.path(percentEncoded: false)) else { return }

        try fileManager.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm"] {
            let file = URL(filePath: storeURL.path(percentEncoded: false) + suffix)
            guard fileManager.fileExists(atPath: file.path(percentEncoded: false)) else { continue }
            try fileManager.copyItem(at: file, to: backupFolder.appending(path: file.lastPathComponent))
        }
        AppLogger.log("Copied the \(storeVersions) store to \(backupFolder.lastPathComponent) before migrating")
    }
}
