import SwiftUI

#if os(iOS)
import UIKit
#endif

private enum OrbitSegmentedControlLayout {
    static let spacing: CGFloat = 8
    static let containerPadding: CGFloat = 6
    static let segmentHorizontalPadding: CGFloat = 16
    static let segmentVerticalPadding: CGFloat = 10
}

struct OrbitSegmentedControl<SelectionValue: Hashable>: View {
    let title: LocalizedStringKey
    @Binding var selection: SelectionValue
    let options: [SelectionValue]
    let label: (SelectionValue) -> String

    init(
        _ title: LocalizedStringKey,
        selection: Binding<SelectionValue>,
        options: [SelectionValue],
        label: @escaping (SelectionValue) -> String
    ) {
        self.title = title
        self._selection = selection
        self.options = options
        self.label = label
    }

    var body: some View {
        control
            .animation(.easeInOut(duration: OrbitTheme.Motion.micro), value: selection)
    }

    @ViewBuilder
    private var control: some View {
        if isPhone {
            phonePicker
        } else {
            regularGlassControl
        }
    }

    private var phonePicker: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(label(option))
                    .tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    private var regularGlassControl: some View {
        GlassEffectContainer(spacing: OrbitSegmentedControlLayout.spacing) {
            HStack(spacing: OrbitSegmentedControlLayout.spacing) {
                ForEach(options, id: \.self) { option in
                    regularSegmentButton(for: option)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(OrbitSegmentedControlLayout.containerPadding)
            .glassEffect(.regular.interactive(), in: Capsule())
        }
    }

    private func regularSegmentButton(for option: SelectionValue) -> some View {
        Button {
            selection = option
        } label: {
            Text(label(option))
                .orbitFont(.subheadline, weight: .semibold)
                .foregroundStyle(option == selection ? Color.primary : Color.primary.opacity(0.76))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, OrbitSegmentedControlLayout.segmentHorizontalPadding)
                .padding(.vertical, OrbitSegmentedControlLayout.segmentVerticalPadding)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background {
            Capsule()
                .fill(Color.clear)
        }
        .contentShape(Capsule())
        .orbitPointerCursor()
        .modifier(OrbitGlassSegmentSelectionModifier(isSelected: option == selection))
    }

    private var isPhone: Bool {
#if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
#else
        false
#endif
    }
}

private struct OrbitGlassSegmentSelectionModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if isSelected {
            content
                .glassEffect(
                    .regular
                        .tint(OrbitTheme.Palette.planetIce.opacity(0.30))
                        .interactive(),
                    in: Capsule()
                )
        } else {
            content
        }
    }
}

#if DEBUG
private enum OrbitSegmentedControlPreviewFilter: String, CaseIterable, Identifiable {
    case all
    case completed
    case open
    case createdHere

    var title: String {
        switch self {
        case .all:
            return "All"
        case .completed:
            return "Completed"
        case .open:
            return "Open"
        case .createdHere:
            return "Created Here"
        }
    }
    var id: Self { self }
}

private struct OrbitSegmentedControlPreviewCard: View {
    @State private var selection: OrbitSegmentedControlPreviewFilter = .all
    let layout: OrbitAdaptiveLayoutValue
    let width: CGFloat

    var body: some View {
        ZStack {
            OrbitSpaceBackground()

            VStack(alignment: .leading, spacing: 16) {
                OrbitSegmentedControl(
                    "Task filter",
                    selection: $selection,
                    options: OrbitSegmentedControlPreviewFilter.allCases
                ) { filter in
                    filter.title
                }
                
                Picker("", selection: $selection) {
                    ForEach(OrbitSegmentedControlPreviewFilter.allCases, id: \.self) { filter in
                        Text(filter.title)
                            .tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.extraLarge)
            }
            .padding(20)
            .frame(width: 440, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(OrbitTheme.Palette.glassBorder, lineWidth: 1)
            )
            .padding(24)
        }
        .frame(width: width, height: 220)
        .environment(\.orbitAdaptiveLayout, layout)
    }
}

struct OrbitSegmentedControl_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OrbitSegmentedControlPreviewCard(
                layout: .init(style: .regular, availableWidth: 520),
                width: 520
            )
            .previewDisplayName("Regular")

            OrbitSegmentedControlPreviewCard(
                layout: .init(style: .compact, availableWidth: 360),
                width: 360
            )
            .previewDisplayName("Compact")
        }
        .preferredColorScheme(.dark)
    }
}
#endif
