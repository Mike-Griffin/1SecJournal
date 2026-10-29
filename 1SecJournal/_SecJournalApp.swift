//
//  _SecJournalApp.swift
//  1SecJournal
//
//  Created by Mike Griffin on 3/16/25.
//

import SwiftUI
import SwiftData

@main
struct _SecJournalApp: App {
    private let container = AppModelContainer.make()

    init() {
        AudioSession.configureForPlayback()
    }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let container):
                ContentView()
                    .modelContainer(container)
            case .failure(let error):
                StoreErrorView(error: error)
            }
        }
    }
}

/// Shown instead of the app if the store can't be opened. Nothing is deleted,
/// so the data is still there for a fixed build, and it can be exported meanwhile.
struct StoreErrorView: View {
    let error: Error
    @State private var isPreparingBackup = false
    @State private var backupShareURL: SelectedIdentifiableURL?
    @State private var backupError: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.yellow)
            Text("Your journal couldn't be opened")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Your videos and entries haven't been changed or deleted. Export a backup to keep a copy, and an update can fix this.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                exportBackup()
            } label: {
                if isPreparingBackup {
                    ProgressView()
                } else {
                    Label("Export Backup", systemImage: "externaldrive")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPreparingBackup)
            if let backupError {
                Text(backupError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            Text(String(describing: error))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.top, 8)
        }
        .padding(24)
        .sheet(item: $backupShareURL) { backup in
            ShareSheet(activityItems: [backup.url])
        }
    }

    private func exportBackup() {
        isPreparingBackup = true
        backupError = nil
        Task {
            defer { isPreparingBackup = false }
            do {
                backupShareURL = SelectedIdentifiableURL(url: try await BackupExporter.makeBackup())
            } catch {
                backupError = error.localizedDescription
            }
        }
    }
}
