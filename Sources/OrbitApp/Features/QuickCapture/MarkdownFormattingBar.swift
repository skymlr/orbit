import SwiftUI

struct MarkdownFormattingBar: View {
    let onAction: (MarkdownFormatAction) -> Void

    private let actions: [MarkdownFormatAction] = [
        .bold,
        .italic,
        .underline,
        .strikethrough,
        .heading1,
        .heading2,
        .bulletList,
        .numberedList,
        .taskList,
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(actions, id: \.self) { action in
                Button {
                    onAction(action)
                } label: {
                    Image(systemName: action.iconName)
                        .orbitFont(.caption, weight: .semibold)
                        .frame(width: 28, height: 24)
                }
                .buttonStyle(.plain)
                .orbitInteractiveControl(
                    scale: 1.08,
                    lift: -1.0,
                    shadowColor: Color.white.opacity(0.12),
                    shadowRadius: 4
                )
                .help(action.title)
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
