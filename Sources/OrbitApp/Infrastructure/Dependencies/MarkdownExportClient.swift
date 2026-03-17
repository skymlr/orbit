import Dependencies
import Foundation

struct MarkdownExportClient: Sendable {
    var exportToDirectory: @Sendable (_ sessionIDs: [UUID], _ directoryURL: URL) async throws -> [URL]
    var exportForSharing: @Sendable (_ sessionIDs: [UUID]) async throws -> [URL]
}

extension MarkdownExportClient: DependencyKey {
    static var liveValue: MarkdownExportClient {
        MarkdownExportClient(
            exportToDirectory: { sessionIDs, directoryURL in
                @Dependency(\.focusRepository) var repository
                return try await repository.exportSessionsMarkdown(sessionIDs, directoryURL)
            },
            exportForSharing: { sessionIDs in
                @Dependency(\.focusRepository) var repository

                let directoryURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("OrbitExports", isDirectory: true)
                    .appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                return try await repository.exportSessionsMarkdown(sessionIDs, directoryURL)
            }
        )
    }

    static var testValue: MarkdownExportClient {
        MarkdownExportClient(
            exportToDirectory: { _, _ in [] },
            exportForSharing: { _ in [] }
        )
    }
}

extension DependencyValues {
    var markdownExportClient: MarkdownExportClient {
        get { self[MarkdownExportClient.self] }
        set { self[MarkdownExportClient.self] = newValue }
    }
}
