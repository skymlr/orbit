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
                .font(.subheadline.weight(.semibold))
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
