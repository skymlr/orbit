import SwiftUI

enum SessionInfoSurfaceStyle: Equatable {
    case card
    case presentation
}

struct SessionInfoSurface: View {
    @Environment(\.orbitAdaptiveLayout) private var layout
    let session: FocusSessionRecord
    let endSessionDraft: AppFeature.State.EndSessionDraft?
    let taskDrafts: [AppFeature.State.TaskDraft]
    let style: SessionInfoSurfaceStyle
    let onRename: (String) -> Void
    let onEndSessionTapped: () -> Void
    let onEndSessionConfirm: (String) -> Void
    let onEndSessionCancel: () -> Void

    @State private var isRenaming = false
    @State private var name = ""
    @State private var isEndSessionArmed = false
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        container
            .alert(
                "End Session?",
                isPresented: Binding(
                    get: { endSessionDraft != nil },
                    set: { isPresented in
                        if !isPresented {
                            onEndSessionCancel()
                        }
                    }
                )
            ) {
                Button("End Session", role: .destructive) {
                    onEndSessionConfirm(endSessionName)
                }
                Button("Cancel", role: .cancel) {
                    onEndSessionCancel()
                }
            } message: {
                Text("This will end the current focus session.")
            }
            .task(id: session.id) {
                name = session.name
                isRenaming = false
                isEndSessionArmed = false
            }
            .onChange(of: session.name) { _, newValue in
                if !isRenaming {
                    name = newValue
                }
            }
            .task(id: isEndSessionArmed) {
                guard isEndSessionArmed else { return }
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                isEndSessionArmed = false
            }
    }

    @ViewBuilder
    private var container: some View {
        switch style {
        case .card:
            panel

        case .presentation:
            ScrollView {
                panel
                    .frame(
                        maxWidth: layout.isCompact ? .infinity : 420,
                        alignment: .leading
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(layout.isCompact ? 16 : 18)
            }
            .scrollIndicators(.hidden)
            .frame(
                minWidth: layout.isCompact ? nil : 320,
                idealWidth: layout.isCompact ? nil : 420,
                minHeight: 280
            )
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            metricsGrid
            if isRenaming {
                actionRow
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .overlay {
            panelShape
                .stroke(panelStroke, lineWidth: 1)
        }
        .clipShape(panelShape)
        .shadow(color: OrbitTheme.Palette.heroCyan.opacity(0.18), radius: 14, y: 6)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusButton

            nameEditor
        }
    }

    @ViewBuilder
    private var nameEditor: some View {
        if isRenaming {
            TextField("Session name", text: $name)
                .textFieldStyle(.roundedBorder)
                .orbitFont(.title2, weight: .bold)
                .focused($isNameFieldFocused)
                .onSubmit {
                    saveRenaming()
                }
                .orbitOnExitCommand {
                    cancelRenaming()
                }
        } else {
            HStack(spacing: 8) {
                Text(session.name)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                Image(systemName: "pencil")
                    .orbitFont(.subheadline, weight: .semibold)
                    .foregroundStyle(OrbitTheme.Palette.starlight.opacity(0.82))
            }
                .orbitFont(.title2, weight: .bold)
                .foregroundStyle(.white)
                .contentShape(Rectangle())
                .orbitPointerCursor()
                .onTapGesture {
                    beginRenaming()
                }
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(
                        minimum: style == .card
                            ? 128
                            : (layout.isCompact ? 120 : 136)
                    ),
                    spacing: 10,
                    alignment: .leading
                )
            ],
            alignment: .leading,
            spacing: 10
        ) {
            SessionInfoMetricTile(title: "Started", systemImage: "play.circle.fill") {
                Text(session.startedAt, style: .time)
            }

            SessionInfoMetricTile(title: "Elapsed", systemImage: "timer") {
                Text(session.startedAt, style: .timer)
            }

            SessionInfoMetricTile(title: "Ends At", systemImage: "clock.fill") {
                Text(boundaryTimeText)
            }

            SessionInfoMetricTile(title: "Open", systemImage: "clock.arrow.circlepath") {
                Text("\(openTaskCount)")
            }

            SessionInfoMetricTile(title: "Completed", systemImage: "checkmark.circle.fill") {
                Text("\(completedTaskCount)")
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            renamingControls
            Spacer(minLength: 0)
        }
    }

    private var renamingControls: some View {
        HStack(spacing: 10) {
            Button("Cancel") {
                cancelRenaming()
            }
            .buttonStyle(.orbitSecondary)

            Button("Save") {
                saveRenaming()
            }
            .buttonStyle(.orbitPrimary)
            .disabled(trimmedName.isEmpty)
        }
    }

    private var statusButton: some View {
        Button {
            statusButtonTapped()
        } label: {
            if isEndSessionArmed {
                HStack(spacing: 6) {
                    Image(systemName: "stop.fill")
                        .orbitFont(.caption2, weight: .bold)
                    Text("End Session")
                        .orbitFont(.caption2, weight: .black)
                        .textCase(.uppercase)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.22))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.red.opacity(0.56), lineWidth: 1)
                )
            } else {
                HStack(spacing: 6) {
                    Circle()
                        .fill(OrbitTheme.Palette.completionGreen)
                        .frame(width: 7, height: 7)
                        .shadow(color: OrbitTheme.Palette.completionGreen.opacity(0.55), radius: 5)

                    Text("Active")
                        .orbitFont(.caption2, weight: .black)
                        .textCase(.uppercase)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isEndSessionArmed ? "End Session" : "Session Active")
        .accessibilityHint(
            isEndSessionArmed
                ? "Tap to end the current session"
                : "Tap to reveal the end session action"
        )
        .animation(.easeInOut(duration: OrbitTheme.Motion.micro), value: isEndSessionArmed)
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: OrbitTheme.Radius.hero, style: .continuous)
    }

    private var panelStroke: Color {
        OrbitTheme.Palette.glassBorderStrong.opacity(0.92)
    }

    private var boundaryTimeText: String {
        FocusDefaults.nextSessionBoundary(after: session.startedAt).formatted(
            date: .omitted,
            time: .shortened
        )
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var endSessionName: String {
        if isRenaming, !trimmedName.isEmpty {
            return trimmedName
        }
        return endSessionDraft?.name ?? session.name
    }

    private var completedTaskCount: Int {
        taskDrafts.reduce(into: 0) { count, task in
            if task.completedAt != nil {
                count += 1
            }
        }
    }

    private var openTaskCount: Int {
        max(0, taskDrafts.count - completedTaskCount)
    }

    private func beginRenaming() {
        isEndSessionArmed = false
        isRenaming = true
        DispatchQueue.main.async {
            isNameFieldFocused = true
        }
    }

    private func saveRenaming() {
        guard !trimmedName.isEmpty else { return }
        onRename(trimmedName)
        isRenaming = false
    }

    private func cancelRenaming() {
        name = session.name
        isRenaming = false
    }

    private func statusButtonTapped() {
        guard isEndSessionArmed else {
            isEndSessionArmed = true
            return
        }
        isEndSessionArmed = false
        onEndSessionTapped()
    }
}

private struct SessionInfoMetricTile<Value: View>: View {
    let title: String
    let systemImage: String
    let value: () -> Value

    init(
        title: String,
        systemImage: String,
        @ViewBuilder value: @escaping () -> Value
    ) {
        self.title = title
        self.systemImage = systemImage
        self.value = value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .orbitFont(.caption2, weight: .semibold)
                .foregroundStyle(OrbitTheme.Palette.starlight.opacity(0.78))
                .labelStyle(.titleAndIcon)

            value()
                .orbitFont(.caption, weight: .bold, monospacedDigits: true)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: OrbitTheme.Radius.card, style: .continuous)
                .fill(Color.white.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: OrbitTheme.Radius.card, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}
