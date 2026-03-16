import ComposableArchitecture
import SwiftUI

struct MenuBarView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let activeSession = store.activeSession {
                ActiveSessionMenuCard(
                    session: activeSession,
                    taskDrafts: Array(store.taskDrafts),
                    hotkeys: store.hotkeys,
                    onSessionTapped: {
                        dismissMenuThen {
                            store.send(.startSessionTapped)
                        }
                    },
                    onCaptureTapped: {
                        dismissMenuThen {
                            store.send(.captureTapped)
                        }
                    }
                )
                .transition(contentTransition)
            } else {
                Button {
                    dismissMenuThen {
                        store.send(.startSessionTapped)
                    }
                } label: {
                    sessionHeroLabel(shortcut: store.hotkeys.startShortcut)
                }
                .buttonStyle(.orbitHero)
                .help("Start Session \(HotkeyHintFormatter.hint(from: store.hotkeys.startShortcut))")
                .transition(contentTransition)
            }
        }
        .padding(14)
        .frame(width: 360)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: OrbitTheme.Motion.standard),
            value: store.activeSession?.id
        )
        .background {
            ZStack {
                OrbitSpaceBackground()

                RoundedRectangle(cornerRadius: OrbitTheme.Radius.panel, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.44))

                RoundedRectangle(cornerRadius: OrbitTheme.Radius.panel, style: .continuous)
                    .stroke(OrbitTheme.Palette.glassBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: OrbitTheme.Radius.panel, style: .continuous))
        }
    }
}

private extension MenuBarView {
    var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Orbit: A Focus Manager")
                .orbitFont(.headline)

            if store.activeSession == nil {
                Text("No active session")
                    .orbitFont(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var contentTransition: AnyTransition {
        reduceMotion ? .opacity : .orbitMicro
    }

    func dismissMenuThen(_ action: @escaping () -> Void) {
        dismiss()
        action()
    }

    @ViewBuilder
    func sessionHeroLabel(shortcut: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "atom")
                    .orbitFont(.title3, weight: .semibold)
                Text("Start Session")
                    .orbitFont(.title3, weight: .bold)
                Spacer()
                HotkeyHintLabel(shortcut: shortcut, tone: .inverted)
                    .orbitFont(.caption, weight: .semibold, monospacedDigits: true)
            }

            Text("Ignite a new focus orbit")
                .orbitFont(.caption)
                .foregroundStyle(.white.opacity(0.86))
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    func hotkeyButtonLabel(title: String, shortcut: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer(minLength: 8)
            HotkeyHintLabel(shortcut: shortcut)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ActiveSessionMenuCard: View {
    let session: FocusSessionRecord
    let taskDrafts: [AppFeature.State.TaskDraft]
    let hotkeys: HotkeySettings
    let onSessionTapped: () -> Void
    let onCaptureTapped: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    eyebrowRow

                    Text(session.name)
                        .orbitFont(.title2, weight: .bold)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                MenuBarSessionAccent()
                    .frame(width: 82, height: 82)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 8) {
                MenuBarMetricChip(
                    title: "Open",
                    value: "\(openTaskCount)",
                    systemImage: "clock.arrow.circlepath"
                )

                MenuBarMetricChip(
                    title: "Completed",
                    value: "\(completedTaskCount)",
                    systemImage: "checkmark.circle.fill"
                )

                MenuBarMetricChip(
                    title: "Ends",
                    value: boundaryTimeText,
                    systemImage: "clock.fill"
                )
            }

            HStack(spacing: 10) {
                Button(action: onSessionTapped) {
                    hotkeyButtonLabel(
                        title: "Session",
                        shortcut: hotkeys.startShortcut
                    )
                }
                .buttonStyle(.orbitPrimary)
                .help("Open or Start Session \(HotkeyHintFormatter.hint(from: hotkeys.startShortcut))")

                Button(action: onCaptureTapped) {
                    hotkeyButtonLabel(
                        title: "Capture",
                        shortcut: hotkeys.captureShortcut
                    )
                }
                .buttonStyle(.orbitSecondary)
                .help("Capture Task \(HotkeyHintFormatter.hint(from: hotkeys.captureShortcut))")
            }
        }
        .padding(14)
        .background(cardBackground)
        .overlay {
            cardShape
                .stroke(OrbitTheme.Palette.glassBorderStrong.opacity(0.92), lineWidth: 1.1)
        }
        .clipShape(cardShape)
        .shadow(color: OrbitTheme.Palette.heroCyan.opacity(0.16), radius: 14, y: 6)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: OrbitTheme.Motion.micro),
            value: taskDrafts.count
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: OrbitTheme.Motion.micro),
            value: completedTaskCount
        )
    }
}

private extension ActiveSessionMenuCard {
    var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: OrbitTheme.Radius.hero, style: .continuous)
    }

    var eyebrowRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                statusPill
                timingRow
            }

            VStack(alignment: .leading, spacing: 6) {
                statusPill
                timingRow
            }
        }
    }

    var statusPill: some View {
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

    var timingRow: some View {
        HStack(spacing: 6) {
            Text("Started \(session.startedAt, style: .time)")
            Text("•")
            Text("Elapsed \(session.startedAt, style: .timer)")
        }
        .orbitFont(.caption2, weight: .medium, monospacedDigits: true)
        .foregroundStyle(OrbitTheme.Palette.starlight.opacity(0.84))
        .lineLimit(1)
        .minimumScaleFactor(0.88)
    }

    var cardBackground: some View {
        ZStack {
            cardShape
                .fill(.ultraThinMaterial)

            cardShape
                .fill(OrbitTheme.Gradients.taskInfoPanel.opacity(0.86))

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 96, height: 96)
                .offset(x: 86, y: -68)
                .blur(radius: 16)
        }
    }

    var completedTaskCount: Int {
        taskDrafts.reduce(into: 0) { count, task in
            if task.completedAt != nil {
                count += 1
            }
        }
    }

    var openTaskCount: Int {
        max(0, taskDrafts.count - completedTaskCount)
    }

    var boundaryTimeText: String {
        FocusDefaults.nextSessionBoundary(after: session.startedAt).formatted(
            date: .omitted,
            time: .shortened
        )
    }

    @ViewBuilder
    func hotkeyButtonLabel(title: String, shortcut: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer(minLength: 8)
            HotkeyHintLabel(shortcut: shortcut)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MenuBarMetricChip: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .orbitFont(.caption2, weight: .semibold)
                .foregroundStyle(OrbitTheme.Palette.starlight.opacity(0.78))
                .labelStyle(.titleAndIcon)

            Text(value)
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

private struct MenuBarSessionAccent: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let outerOrbitDiameter = size * 0.96
            let innerOrbitDiameter = size * 0.72
            let outerPlanetOffset = orbitOffset(radius: outerOrbitDiameter / 2, angleDegrees: 211)
            let innerPlanetOffset = orbitOffset(radius: innerOrbitDiameter / 2, angleDegrees: 36)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                OrbitTheme.Palette.sunHalo.opacity(0.45),
                                OrbitTheme.Palette.sunFlare.opacity(0.20),
                                .clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: size * 0.52
                        )
                    )
                    .frame(width: outerOrbitDiameter, height: outerOrbitDiameter)

                Circle()
                    .stroke(OrbitTheme.Palette.orbitLine.opacity(0.18), lineWidth: 1)
                    .frame(width: outerOrbitDiameter, height: outerOrbitDiameter)

                Circle()
                    .stroke(OrbitTheme.Palette.orbitLine.opacity(0.12), lineWidth: 0.9)
                    .frame(width: innerOrbitDiameter, height: innerOrbitDiameter)

                Circle()
                    .fill(OrbitTheme.Gradients.sunCore)
                    .frame(width: size * 0.26, height: size * 0.26)
                    .shadow(color: OrbitTheme.Palette.sunFlare.opacity(0.42), radius: 8)

                Circle()
                    .fill(OrbitTheme.Palette.planetGold)
                    .frame(width: size * 0.13, height: size * 0.13)
                    .offset(x: outerPlanetOffset.width, y: outerPlanetOffset.height)
                    .shadow(color: OrbitTheme.Palette.planetGold.opacity(0.30), radius: 5)

                Circle()
                    .fill(OrbitTheme.Palette.planetIce)
                    .frame(width: size * 0.10, height: size * 0.10)
                    .offset(x: innerPlanetOffset.width, y: innerPlanetOffset.height)
                    .shadow(color: OrbitTheme.Palette.planetIce.opacity(0.30), radius: 5)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func orbitOffset(radius: CGFloat, angleDegrees: CGFloat) -> CGSize {
        let radians = angleDegrees * (.pi / 180)
        return CGSize(
            width: cos(radians) * radius,
            height: sin(radians) * radius
        )
    }
}

#if DEBUG
private extension MenuBarView {
    static var activePreviewStore: StoreOf<AppFeature> {
        let startedAt = Date(timeIntervalSince1970: 1_741_640_200)
        let project = NoteCategoryRecord(
            id: UUID(uuidString: "0DAE8858-A53A-4C9A-9DE2-FC443FDCCDC0")!,
            name: "Launch",
            colorHex: "#58B5FF"
        )
        let writing = NoteCategoryRecord(
            id: UUID(uuidString: "D46017E0-51E3-4D31-B8E9-C1440A1EE75E")!,
            name: "Copy",
            colorHex: "#F2C94C"
        )
        let tasks = [
            FocusTaskRecord(
                id: UUID(uuidString: "BB86F6DB-BE36-4262-B6C0-EA2954F42358")!,
                sessionID: UUID(uuidString: "A4D1AA12-6C55-420B-B1F9-FDDB5904A739")!,
                categories: [project, writing],
                markdown: "Polish the menu card visuals",
                priority: .high,
                completedAt: nil,
                carriedFromTaskID: nil,
                carriedFromSessionName: nil,
                createdAt: startedAt.addingTimeInterval(1_200),
                updatedAt: startedAt.addingTimeInterval(1_260)
            ),
            FocusTaskRecord(
                id: UUID(uuidString: "3D0AA8D3-7FF6-404D-8DF0-EA34EF353905")!,
                sessionID: UUID(uuidString: "A4D1AA12-6C55-420B-B1F9-FDDB5904A739")!,
                categories: [project],
                markdown: "Review menu hierarchy",
                priority: .medium,
                completedAt: startedAt.addingTimeInterval(900),
                carriedFromTaskID: nil,
                carriedFromSessionName: nil,
                createdAt: startedAt.addingTimeInterval(600),
                updatedAt: startedAt.addingTimeInterval(930)
            ),
        ]

        var state = AppFeature.State()
        state.activeSession = FocusSessionRecord(
            id: UUID(uuidString: "A4D1AA12-6C55-420B-B1F9-FDDB5904A739")!,
            name: "Deep Work: Ship the Menu Card",
            startedAt: startedAt,
            endedAt: nil,
            endedReason: nil,
            tasks: tasks
        )
        state.taskDrafts = [
            AppFeature.State.TaskDraft(
                id: tasks[0].id,
                categories: tasks[0].categories,
                markdown: tasks[0].markdown,
                priority: tasks[0].priority,
                completedAt: tasks[0].completedAt,
                carriedFromTaskID: tasks[0].carriedFromTaskID,
                carriedFromSessionName: tasks[0].carriedFromSessionName,
                createdAt: tasks[0].createdAt
            ),
            AppFeature.State.TaskDraft(
                id: tasks[1].id,
                categories: tasks[1].categories,
                markdown: tasks[1].markdown,
                priority: tasks[1].priority,
                completedAt: tasks[1].completedAt,
                carriedFromTaskID: tasks[1].carriedFromTaskID,
                carriedFromSessionName: tasks[1].carriedFromSessionName,
                createdAt: tasks[1].createdAt
            ),
        ]
        return Store(initialState: state) {
            AppFeature()
        }
    }

    static var inactivePreviewStore: StoreOf<AppFeature> {
        Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    }
}

struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MenuBarView(store: MenuBarView.activePreviewStore)
                .preferredColorScheme(.dark)
                .previewDisplayName("Active Session")

            MenuBarView(store: MenuBarView.inactivePreviewStore)
                .preferredColorScheme(.dark)
                .previewDisplayName("No Active Session")
        }
        .padding()
        .frame(width: 388)
        .background(Color.black)
    }
}
#endif
