import SwiftUI

struct PreferencesCompactIndexView<Destination: View>: View {
    let sections: [PreferencesSection]
    let destination: (PreferencesSection) -> Destination

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(sections) { section in
                    NavigationLink {
                        destination(section)
                            .navigationTitle(section.title)
                            .orbitInlineNavigationTitleDisplayMode()
                    } label: {
                        OrbitIndexCard(
                            systemImage: section.symbolName,
                            title: section.title,
                            subtitle: section.subtitle
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
#if os(iOS)
        .scrollIndicators(.hidden)
#endif
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Settings")
        .orbitInlineNavigationTitleDisplayMode()
    }
}

struct PreferencesAppearanceSaveCalloutView: View {
    let hasUnsavedChanges: Bool
    let fill: Color
    let stroke: Color
    let iconBackground: Color
    let iconColor: Color
    let resetAction: () -> Void
    let saveAction: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                summary
                Spacer(minLength: 12)
                actionButtons
            }

            VStack(alignment: .leading, spacing: 14) {
                summary
                actionButtons
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: OrbitTheme.Radius.card, style: .continuous)
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OrbitTheme.Radius.card, style: .continuous)
                .stroke(stroke, lineWidth: 1)
        )
    }

    private var summary: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconBackground)

                Image(systemName: hasUnsavedChanges ? "square.and.arrow.down.fill" : "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(hasUnsavedChanges ? "Unsaved appearance changes" : "Appearance is saved")
                    .orbitFont(.callout, weight: .semibold)

                Text(
                    hasUnsavedChanges
                        ? "Save to apply this canvas across Orbit and keep it the next time the app opens."
                        : "This canvas is already applied across Orbit and saved for future launches."
                )
                .orbitFont(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button("Reset Appearance", action: resetAction)
                .buttonStyle(.orbitSecondary)

            Button(action: saveAction) {
                Label(
                    hasUnsavedChanges ? "Save Appearance" : "Appearance Saved",
                    systemImage: hasUnsavedChanges ? "square.and.arrow.down" : "checkmark.circle"
                )
            }
            .buttonStyle(.orbitPrimary)
            .disabled(!hasUnsavedChanges)
            .opacity(hasUnsavedChanges ? 1 : 0.72)
        }
    }
}

struct PreferencesBackgroundOptionCardView: View {
    let option: OrbitBackgroundOption
    let showsOrbitalLayer: Bool
    let isSelected: Bool
    let previewSubtitle: String
    let fillColor: Color
    let strokeColor: Color
    let indicatorColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                OrbitSpaceBackground(
                    style: option,
                    showsOrbitalLayer: showsOrbitalLayer
                )
                .frame(maxWidth: .infinity)
                .frame(height: 88)
                .clipShape(RoundedRectangle(cornerRadius: OrbitTheme.Radius.medium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: OrbitTheme.Radius.medium, style: .continuous)
                        .stroke(OrbitTheme.Palette.glassBorder, lineWidth: 1)
                )

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(option.title)
                            .orbitFont(.body, weight: .semibold)

                        Text(previewSubtitle)
                            .orbitFont(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(indicatorColor)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: OrbitTheme.Radius.card, style: .continuous)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OrbitTheme.Radius.card, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: OrbitTheme.Radius.card, style: .continuous))
    }
}

struct PreferencesSyncStatusCardView: View {
    let title: String
    let message: String
    let showsRetry: Bool
    let retryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .orbitFont(.body, weight: .semibold)

                Text(message)
                    .orbitFont(.caption)
                    .foregroundStyle(.secondary)
            }

            if showsRetry {
                Button("Retry Sync", action: retryAction)
                    .buttonStyle(.orbitSecondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: OrbitTheme.Radius.card, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: OrbitTheme.Radius.card, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
}
