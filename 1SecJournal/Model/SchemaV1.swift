//
//  SchemaV1.swift
//  1SecJournal
//
//  Created by Mike Griffin on 10/27/26.
//
import SwiftData
import Foundation

/// The models as they shipped before versioning, frozen so existing stores can be
/// recognized and migrated. Don't change anything here: the stored properties,
/// their types, and the relationships must match the old store exactly.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [VideoEntry.self, DailyVideoEntry.self, StitchedVideoEntry.self]
    }

    @Model class VideoEntry {
        var id: UUID
        var filename: String
        var thumbnailFilename: String
        var date: Date

        init(filename: String, thumbnailFilename: String) {
            self.id = UUID()
            self.filename = filename
            self.thumbnailFilename = thumbnailFilename
            self.date = Date()
        }
    }

    @available(iOS 26.0, *)
    @Model
    class DailyVideoEntry: VideoEntry {
        var stitchedVideos: [StitchedVideoEntry] = []

        override init(filename: String, thumbnailFilename: String) {
            super.init(filename: filename, thumbnailFilename: thumbnailFilename)
        }
    }

    @available(iOS 26.0, *)
    @Model
    class StitchedVideoEntry: VideoEntry {
        var composingVideos: [DailyVideoEntry]

        init(filename: String, thumbnailFilename: String, composingVideos: [DailyVideoEntry]) {
            self.composingVideos = composingVideos
            super.init(filename: filename, thumbnailFilename: thumbnailFilename)
        }
    }
}
