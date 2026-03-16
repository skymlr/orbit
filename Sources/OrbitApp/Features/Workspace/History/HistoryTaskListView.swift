import SwiftUI

struct HistoryTaskListView: View {
    let session: FocusSessionRecord
    let filteredTasks: [FocusTaskRecord]
    @Binding var historyTaskFilter: HistoryTaskFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.title3.weight(.semibold))

                HStack(spacing: 8) {
                    Text("Started \(session.startedAt, style: .time)")

                    if let endedAt = session.endedAt {
                        Text("•")
                        Text("Ended \(endedAt, style: .time)")
                    }

                    Text("•")
                    Text("\(session.tasks.count) \(session.tasks.count == 1 ? "task" : "tasks")")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            OrbitSegmentedControl(
                "Task filter",
                selection: $historyTaskFilter,
                options: HistoryTaskFilter.sessionHistoryTabs
            ) { filter in
                filter.title
            }
            .frame(maxWidth: 440)

            if filteredTasks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No tasks for this filter")
                        .font(.subheadline.weight(.semibold))
                    Text("Try switching between Completed, All, Open, and Created Here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.thinMaterial)
                )
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(filteredTasks) { task in
                            HistoryTaskRowView(task: task)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.visible)
            }
        }
    }
}
