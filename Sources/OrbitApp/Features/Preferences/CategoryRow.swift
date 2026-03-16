import SwiftUI

struct CategoryRow: View {
    let category: SessionCategoryRecord
    let onRename: (String, String) -> Void
    let onDelete: () -> Void

    @State private var name = ""
    @State private var selectedColorHex = FocusDefaults.defaultCategoryColorHex

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Category", text: $name)
                    .textFieldStyle(.roundedBorder)

                Button("Save") {
                    onRename(name, selectedColorHex)
                }
                .buttonStyle(.orbitSecondary)

                Button("Delete", role: .destructive) {
                    onDelete()
                }
                .buttonStyle(.orbitDestructive)
            }

            CategoryColorPalettePicker(selectedHex: $selectedColorHex)
        }
        .task(id: category.id) {
            name = category.name
            let normalized = FocusDefaults.normalizedCategoryColorHex(category.colorHex)
            if FocusDefaults.categoryColorOptions.contains(normalized) {
                selectedColorHex = normalized
            } else {
                selectedColorHex = FocusDefaults.defaultCategoryColorHex
            }
        }
    }
}
