import SwiftUI

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
        Group {
            if #available(macOS 26.0, *) {
                glassControl
            } else {
                standardControl
            }
        }
        .animation(.easeInOut(duration: OrbitTheme.Motion.micro), value: selection)
    }

    private var standardControl: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(label(option))
                    .tag(option)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
    }

    @available(macOS 26.0, *)
    private var glassControl: some View {
        GlassEffectContainer(spacing: OrbitSegmentedControlLayout.spacing) {
            HStack(spacing: OrbitSegmentedControlLayout.spacing) {
                ForEach(options, id: \.self) { option in
                    segmentButton(for: option)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(OrbitSegmentedControlLayout.containerPadding)
            .glassEffect(.regular.interactive(), in: Capsule())
        }
    }

    @available(macOS 26.0, *)
    private func segmentButton(for option: SelectionValue) -> some View {
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
}

@available(macOS 26.0, *)
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
        .frame(width: 520, height: 220)
    }
}

struct OrbitSegmentedControl_Previews: PreviewProvider {
    static var previews: some View {
        OrbitSegmentedControlPreviewCard()
            .preferredColorScheme(.dark)
    }
}
#endif
