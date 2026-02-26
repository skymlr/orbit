import Foundation

struct Session: Equatable, Identifiable, Sendable {
    var id: String { fileName }

    var title: String
    var tags: [SessionTag]
    var startedAt: Date
    var endedAt: Date?
    var items: [CapturedItem]

    var fileName: String {
        "\(Self.fileNameDateFormatter.string(from: startedAt))-focus.md"
    }

    private static let fileNameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter
    }()
}
