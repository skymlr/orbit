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
        let tags = session.tags
            .map(\.name)
            .joined(separator: ", ")

        var sections: [String] = [
            "# Session: \(session.title) - \(headerDateFormatter().string(from: session.startedAt))",
            "Tags: \(tags)",
            "Started: \(headerDateFormatter().string(from: session.startedAt))",
        ]

        if let endedAt = session.endedAt {
            sections.append("Ended: \(headerDateFormatter().string(from: endedAt))")
        }

        sections.append("")
        sections.append("## Captured Items")
        sections.append("")

        for item in session.items.sorted(by: { $0.timestamp < $1.timestamp }) {
            sections.append("### \(itemTimeFormatter().string(from: item.timestamp)) - \(item.type.prefix)")
            sections.append(item.content)
            sections.append("")
        }

        return sections.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n"
    }

    static func parse(markdown: String, fileURL: URL) throws -> Session {
        if let newSession = try? parseNew(markdown: markdown) {
            return newSession
        }

        return try parseLegacy(markdown: markdown)
    }

    private static func parseNew(markdown: String) throws -> Session {
        let lines = markdown.components(separatedBy: .newlines)
        guard let firstLine = lines.first, !firstLine.isEmpty else {
            throw SessionStoreError.invalidMarkdown("Missing session header")
        }

        var headerInput = firstLine[...]
        let header: NewSessionHeaderParser.Output
        do {
            header = try NewSessionHeaderParser().parse(&headerInput)
        } catch {
            throw SessionStoreError.invalidMarkdown("Invalid new session header")
        }

        guard let headerStart = headerDateFormatter().date(from: String(header.dateText)) else {
            throw SessionStoreError.invalidMarkdown("Invalid session start date")
        }

        var tags: [SessionTag] = []
        var startedAt = headerStart
        var endedAt: Date?
        var sawNewFormatMetadata = false

        for line in lines.dropFirst() {
            if line.hasPrefix("Tags:") {
                sawNewFormatMetadata = true
                tags = tagsFromLine(line)
            } else if line.hasPrefix("Started:") {
                sawNewFormatMetadata = true
                let value = line.dropFirst("Started:".count).trimmingCharacters(in: .whitespaces)
                if let parsed = headerDateFormatter().date(from: value) {
                    startedAt = parsed
                }
            } else if line.hasPrefix("Ended:") {
                sawNewFormatMetadata = true
                let value = line.dropFirst("Ended:".count).trimmingCharacters(in: .whitespaces)
                if let parsed = headerDateFormatter().date(from: value) {
                    endedAt = parsed
                }
            }
        }

        guard sawNewFormatMetadata else {
            throw SessionStoreError.invalidMarkdown("Missing new session metadata")
        }

        let items = parseItems(lines: lines, startedAt: startedAt)

        return Session(
            title: normalizedSessionTitle(String(header.titleText)),
            tags: tags,
            startedAt: startedAt,
            endedAt: endedAt,
            items: items
        )
    }

    private static func parseLegacy(markdown: String) throws -> Session {
        let lines = markdown.components(separatedBy: .newlines)
        guard let firstLine = lines.first, !firstLine.isEmpty else {
            throw SessionStoreError.invalidMarkdown("Missing session header")
        }

        var headerInput = firstLine[...]
        let header: LegacySessionHeaderParser.Output
        do {
            header = try LegacySessionHeaderParser().parse(&headerInput)
        } catch {
            throw SessionStoreError.invalidMarkdown("Could not parse legacy session header")
        }

        guard let startedAt = headerDateFormatter().date(from: String(header.dateText)) else {
            throw SessionStoreError.invalidMarkdown("Invalid session date")
        }

        let items = parseItems(lines: lines, startedAt: startedAt)

        return Session(
            title: "Focus",
            tags: [header.mode.builtInTag],
            startedAt: startedAt,
            endedAt: nil,
            items: items
        )
    }

    private static func parseItems(lines: [String], startedAt: Date) -> [CapturedItem] {
        var items: [CapturedItem] = []
        let dayPrefix = dayDateFormatter().string(from: startedAt)

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
                    timestamp: itemDate,
                    type: itemHeader.type
                )
            )
        }

        return items
    }

    private static func tagsFromLine(_ line: String) -> [SessionTag] {
        let raw = line.dropFirst("Tags:".count).trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return [] }

        let builtInByName = Dictionary(uniqueKeysWithValues: SessionTag.builtIns.map { ($0.name, $0) })
        var seen = Set<String>()
        var tags: [SessionTag] = []

        for component in raw.split(separator: ",") {
            let normalized = component.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)

            if let builtIn = builtInByName[normalized] {
                tags.append(builtIn)
            } else {
                tags.append(SessionTag(id: UUID(), name: normalized, isBuiltIn: false))
            }
        }

        return tags
    }

    private static func normalizedSessionTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "Focus Session" {
            return "Focus"
        }
        return trimmed.isEmpty ? "Focus" : trimmed
    }

    private struct NewSessionHeaderParser: Parser {
        struct Output {
            var titleText: Substring
            var dateText: Substring
        }

        var body: some Parser<Substring, Output> {
            Parse(Output.init(titleText:dateText:)) {
                "# Session: "
                Prefix(1...) { $0 != "-" }
                "- "
                Rest()
            }
        }
    }

    private struct LegacySessionHeaderParser: Parser {
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

private extension FocusMode {
    var builtInTag: SessionTag {
        switch self {
        case .coding:
            return SessionTag.builtIns[0]
        case .researching:
            return SessionTag.builtIns[1]
        case .email:
            return SessionTag.builtIns[2]
        case .meeting:
            return SessionTag.builtIns[3]
        }
    }
}
