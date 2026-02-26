import Dependencies
import Foundation
import Parsing

enum SessionStoreError: Error, Equatable, Sendable {
    case directoryUnavailable
    case writeFailed(String)
    case readFailed(String)
    case invalidMarkdown(String)
}

struct SessionStore: Sendable {
    var save: @Sendable (Session) async throws -> Void
    var load: @Sendable (Date) async throws -> Session?
    var listSessions: @Sendable () async throws -> [Session]
}

extension SessionStore: DependencyKey {
    static var liveValue: SessionStore {
        let fileStore = SessionFileStore()
        return SessionStore(
            save: { session in
                try await fileStore.save(session)
            },
            load: { date in
                try await fileStore.load(closestTo: date)
            },
            listSessions: {
                try await fileStore.listSessions()
            }
        )
    }

    static var testValue: SessionStore {
        SessionStore(
            save: { _ in },
            load: { _ in nil },
            listSessions: { [] }
        )
    }
}

extension DependencyValues {
    var sessionStore: SessionStore {
        get { self[SessionStore.self] }
        set { self[SessionStore.self] = newValue }
    }
}

enum SessionMarkdownCodec {
    static func render(_ session: Session) -> String {
        var sections: [String] = [
            "# Session: \(session.mode.config.displayName) - \(headerDateFormatter().string(from: session.startedAt))",
            "",
            "## Captured Items",
            "",
        ]

        for item in session.items.sorted(by: { $0.timestamp < $1.timestamp }) {
            sections.append("### \(itemTimeFormatter().string(from: item.timestamp)) - \(item.type.prefix)")
            sections.append(item.content)
            sections.append("")
        }

        return sections.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n"
    }

    static func parse(markdown: String, fileURL: URL) throws -> Session {
        let lines = markdown.components(separatedBy: .newlines)
        guard let firstLine = lines.first, !firstLine.isEmpty else {
            throw SessionStoreError.invalidMarkdown("Missing session header")
        }

        var headerInput = firstLine[...]
        let mode: FocusMode
        let startDateString: String

        do {
            let parsed = try SessionHeaderParser().parse(&headerInput)
            mode = parsed.mode
            startDateString = String(parsed.dateText)
        } catch {
            throw SessionStoreError.invalidMarkdown("Could not parse session header")
        }

        guard let startedAt = headerDateFormatter().date(from: startDateString) else {
            throw SessionStoreError.invalidMarkdown("Invalid session date")
        }

        let dayPrefix = dayDateFormatter().string(from: startedAt)

        var items: [CapturedItem] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            var lineInput = line[...]

            guard let itemHeader = try? MarkdownItemHeaderParser().parse(&lineInput) else {
                index += 1
                continue
            }

            var contentLines: [String] = []
            index += 1
            while index < lines.count, !lines[index].hasPrefix("### ") {
                let current = lines[index]
                if !current.isEmpty {
                    contentLines.append(current)
                }
                index += 1
            }

            let content = contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { continue }

            let itemDate = itemTimestampFormatter().date(from: "\(dayPrefix) \(itemHeader.time)") ?? startedAt

            items.append(
                CapturedItem(
                    id: UUID(),
                    content: content,
                    mode: mode,
                    timestamp: itemDate,
                    type: itemHeader.type
                )
            )
        }

        return Session(
            mode: mode,
            startedAt: startedAt,
            endedAt: nil,
            items: items
        )
    }

    private struct SessionHeaderParser: Parser {
        struct Output {
            var mode: FocusMode
            var dateText: Substring
        }

        var body: some Parser<Substring, Output> {
            Parse(Output.init(mode:dateText:)) {
                "# Session: "
                OneOf {
                    "Coding".map { FocusMode.coding }
                    "Researching".map { FocusMode.researching }
                    "Email".map { FocusMode.email }
                    "Meeting".map { FocusMode.meeting }
                }
                " - "
                Rest()
            }
        }
    }

    private struct MarkdownItemHeaderParser: Parser {
        struct Output {
            var time: String
            var type: ItemType
        }

        var body: some Parser<Substring, Output> {
            Parse(Output.init(time:type:)) {
                "### "
                Prefix(1...) { $0 != " " }
                    .map(String.init)
                " - "
                OneOf {
                    "@todo".map { ItemType.todo }
                    "@next".map { ItemType.next }
                    "@note".map { ItemType.note }
                    "@link".map { ItemType.link }
                }
            }
        }
    }

    private static func headerDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }

    private static func dayDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func itemTimeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private static func itemTimestampFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }
}

private actor SessionFileStore {
    private let fileManager = FileManager.default

    func save(_ session: Session) throws {
        let directory = try sessionDirectoryURL()
        let fileURL = directory.appendingPathComponent(session.fileName)
        let markdown = SessionMarkdownCodec.render(session)

        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            throw SessionStoreError.writeFailed(error.localizedDescription)
        }
    }

    func load(closestTo date: Date) throws -> Session? {
        let sessions = try listSessions()
        return sessions.min(by: {
            abs($0.startedAt.timeIntervalSince(date)) < abs($1.startedAt.timeIntervalSince(date))
        })
    }

    func listSessions() throws -> [Session] {
        let directory = try sessionDirectoryURL()

        let urls: [URL]
        do {
            urls = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw SessionStoreError.readFailed(error.localizedDescription)
        }

        var sessions: [Session] = []

        for url in urls where url.pathExtension == "md" {
            do {
                let markdown = try String(contentsOf: url, encoding: .utf8)
                let session = try SessionMarkdownCodec.parse(markdown: markdown, fileURL: url)
                sessions.append(session)
            } catch {
                continue
            }
        }

        return sessions.sorted(by: { $0.startedAt > $1.startedAt })
    }

    private func sessionDirectoryURL() throws -> URL {
        guard let appSupportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw SessionStoreError.directoryUnavailable
        }

        let directory = appSupportDirectory
            .appendingPathComponent("Orbit", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            throw SessionStoreError.directoryUnavailable
        }
    }
}
