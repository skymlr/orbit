import Foundation
import SwiftUI

struct HistoryTaskRowView: View {
    let task: FocusTaskRecord

    private var isCompleted: Bool {
        task.completedAt != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MarkdownRenderedTaskView(markdown: task.markdown)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .strikethrough(isCompleted, color: .secondary)
                .opacity(isCompleted ? 0.72 : 1)

            HStack(alignment: .center, spacing: 8) {
                priorityBadge

                if !task.categories.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(task.categories) { category in
                                OrbitCategoryChip(
                                    title: category.name,
                                    tint: Color(orbitHex: category.colorHex),
                                    isSelected: true
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                }
            }

            HStack(spacing: 8) {
                if let completedAt = task.completedAt {
                    Text("Completed \(completedAt, style: .time)")
                    Text("•")
                } else {
                    Text("Open")
                    Text("•")
                }

                Text("Created \(task.createdAt, style: .time)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.02))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        )
    }

    private var priorityBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: priorityIcon)
                .font(.caption2.weight(.bold))

            Text(task.priority.title)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(priorityColor.opacity(0.25))
        )
        .overlay(
            Capsule()
                .stroke(priorityColor.opacity(0.88), lineWidth: 1)
        )
        .foregroundStyle(priorityColor)
    }

    private var priorityIcon: String {
        switch task.priority {
        case .none:
            return "minus.circle"
        case .low:
            return "arrow.down.circle.fill"
        case .medium:
            return "equal.circle.fill"
        case .high:
            return "exclamationmark.circle.fill"
        }
    }

    private var priorityColor: Color {
        switch task.priority {
        case .none:
            return .secondary
        case .low:
            return Color(red: 0.42, green: 0.82, blue: 0.65)
        case .medium:
            return Color(red: 0.99, green: 0.70, blue: 0.30)
        case .high:
            return Color(red: 1.00, green: 0.45, blue: 0.42)
        }
    }
}
