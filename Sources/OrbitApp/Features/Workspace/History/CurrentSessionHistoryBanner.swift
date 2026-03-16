import SwiftUI

struct CurrentSessionHistoryBanner: View {
    let session: FocusSessionRecord
    let onBackToLiveSession: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Session")
                        .orbitFont(.caption2, weight: .semibold)
                        .foregroundStyle(.secondary)

                    Text(session.name)
                        .orbitFont(.headline, weight: .semibold)
                        .lineLimit(2)
                }

                Spacer()

                Button("Back to Live Session") {
                    onBackToLiveSession()
                }
                .buttonStyle(.orbitPrimary)
            }

            HStack(spacing: 8) {
                Text("\(session.tasks.count) \(session.tasks.count == 1 ? "task" : "tasks")")
                Text("•")
                Text("Started \(session.startedAt, style: .time)")
                Text("•")
                Text("Elapsed \(session.startedAt, style: .timer)")
            }
            .orbitFont(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.cyan.opacity(0.62), lineWidth: 1)
                )
        )
    }
}
