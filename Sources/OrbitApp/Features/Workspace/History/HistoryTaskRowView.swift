import Foundation
import SwiftUI

struct HistoryTaskRowView: View {
    @Environment(\.orbitAdaptiveLayout) private var layout
    let task: FocusTaskRecord

    private var isCompleted: Bool {
        task.completedAt != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MarkdownRenderedTaskView(markdown: task.markdown)
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

            if layout.isCompact {
                VStack(alignment: .leading, spacing: 4) {
                    if let completedAt = task.completedAt {
                        Text("Completed \(completedAt, style: .time)")
                    } else {
                        Text("Open")
                    }

                    Text("Created \(task.createdAt, style: .time)")
                }
                .orbitFont(.caption)
                .foregroundStyle(.secondary)
            } else {
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
                .orbitFont(.caption)
                .foregroundStyle(.secondary)
            }
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
                .orbitFont(.caption2, weight: .bold)

            Text(task.priority.title)
                .lineLimit(1)
        }
        .orbitFont(.caption, weight: .semibold)
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

#if DEBUG
private enum HistoryTaskRowPreviewFixtures {
    static let previewSessionID = UUID(uuidString: "0EDDB08F-D92D-4959-A925-329E8BB68483")!
    static let previewCreatedAt = Date(timeIntervalSinceReferenceDate: 764_553_600)
    static let previewCompletedAt = previewCreatedAt.addingTimeInterval(1_020)

    static let designCategory = NoteCategoryRecord(
        id: UUID(uuidString: "A153D331-5CB8-493E-B2B2-9D6669149675")!,
        name: "Design",
        colorHex: "#FF9F1C"
    )

    static let launchCategory = NoteCategoryRecord(
        id: UUID(uuidString: "E1103727-B2FD-465A-8904-D42733090058")!,
        name: "Launch",
        colorHex: "#00B5FF"
    )

    static let openTask = FocusTaskRecord(
        id: UUID(uuidString: "6D5D0356-304D-4A74-B43E-E763E454E2FD")!,
        sessionID: previewSessionID,
        categories: [designCategory, launchCategory],
        markdown: "Review the archived task card spacing before shipping.",
        priority: .medium,
        completedAt: nil,
        carriedFromTaskID: nil,
        carriedFromSessionName: nil,
        createdAt: previewCreatedAt,
        updatedAt: previewCreatedAt.addingTimeInterval(180)
    )

    static let completedTask = FocusTaskRecord(
        id: UUID(uuidString: "095C4432-AF45-452F-ACAF-043D02FB31C9")!,
        sessionID: previewSessionID,
        categories: [launchCategory],
        markdown: "Publish the preview screenshots for QA review.",
        priority: .high,
        completedAt: previewCompletedAt,
        carriedFromTaskID: UUID(uuidString: "156D1668-7D2C-4194-842F-72F93B3DD408"),
        carriedFromSessionName: "Yesterday Wrap-Up",
        createdAt: previewCreatedAt.addingTimeInterval(-1_200),
        updatedAt: previewCompletedAt
    )
}

private struct HistoryTaskRowPreviewGallery: View {
    let layout: OrbitAdaptiveLayoutValue
    let galleryWidth: CGFloat

    var body: some View {
        ZStack {
            OrbitSpaceBackground()

            VStack(alignment: .leading, spacing: 16) {
                HistoryTaskRowView(task: HistoryTaskRowPreviewFixtures.openTask)
                HistoryTaskRowView(task: HistoryTaskRowPreviewFixtures.completedTask)
            }
            .padding(24)
            .frame(width: galleryWidth, alignment: .leading)
        }
        .frame(width: galleryWidth + 60, height: 300)
        .environment(\.orbitAdaptiveLayout, layout)
    }
}

struct HistoryTaskRowView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HistoryTaskRowPreviewGallery(
                layout: .init(style: .regular, availableWidth: 680),
                galleryWidth: 620
            )
            .previewDisplayName("Regular")

            HistoryTaskRowPreviewGallery(
                layout: .init(style: .compact, availableWidth: 375),
                galleryWidth: 315
            )
            .previewDisplayName("Compact")
        }
        .preferredColorScheme(.dark)
    }
}
#endif
