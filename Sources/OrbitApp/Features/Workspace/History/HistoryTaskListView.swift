import SwiftUI

#if os(iOS)
import UIKit
#endif

struct HistoryTaskListView: View {
    @Environment(\.orbitAdaptiveLayout) private var layout
    let session: FocusSessionRecord
    let filteredTasks: [FocusTaskRecord]
    @Binding var historyTaskFilter: HistoryTaskFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .orbitFont(.title3, weight: .semibold)

                if layout.isCompact {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Started \(session.startedAt, style: .time)")

                        if let endedAt = session.endedAt {
                            Text("Ended \(endedAt, style: .time)")
                        }

                        Text("\(session.tasks.count) \(session.tasks.count == 1 ? "task" : "tasks")")
                    }
                    .orbitFont(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 8) {
                        Text("Started \(session.startedAt, style: .time)")

                        if let endedAt = session.endedAt {
                            Text("•")
                            Text("Ended \(endedAt, style: .time)")
                        }

                        Text("•")
                        Text("\(session.tasks.count) \(session.tasks.count == 1 ? "task" : "tasks")")
                    }
                    .orbitFont(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            OrbitSegmentedControl(
                "Task filter",
                selection: $historyTaskFilter,
                options: HistoryTaskFilter.sessionHistoryTabs
            ) { filter in
                filter.title
            }

            if filteredTasks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No tasks for this filter")
                        .orbitFont(.subheadline, weight: .semibold)
                    Text("Try switching between Completed, All, Open, and Created Here.")
                        .orbitFont(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .orbitSurfaceCard()
            } else {
                Group {
                    if isPhone {
                        taskRows
                    } else {
                        ScrollView {
                            taskRows
                        }
                        .scrollIndicators(.visible)
                    }
                }
            }
        }
    }

    private var taskRows: some View {
        VStack(spacing: 12) {
            ForEach(filteredTasks) { task in
                HistoryTaskRowView(task: task)
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isPhone: Bool {
#if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
#else
        false
#endif
    }
}
