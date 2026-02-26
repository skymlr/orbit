import Dependencies
import Foundation

struct MarkdownExportClient: Sendable {
    var export: @Sendable (_ sessionIDs: [UUID], _ directoryURL: URL) async throws -> [URL]
}

extension MarkdownExportClient: DependencyKey {
    static var liveValue: MarkdownExportClient {
        MarkdownExportClient(
            export: { sessionIDs, directoryURL in
                @Dependency(\.focusRepository) var repository
                return try await repository.exportSessionsMarkdown(sessionIDs, directoryURL)
            }
        )
    }

    static var testValue: MarkdownExportClient {
        MarkdownExportClient(
            export: { _, _ in [] }
        )
    }
}

extension DependencyValues {
    var markdownExportClient: MarkdownExportClient {
        get { self[MarkdownExportClient.self] }
        set { self[MarkdownExportClient.self] = newValue }
    }
}
