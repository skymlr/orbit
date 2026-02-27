import SwiftUI

struct EndSessionPromptView: View {
    let draft: AppFeature.State.EndSessionDraft
    let onConfirm: (String, UUID?) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var selectedCategoryID = FocusDefaults.focusCategoryID

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("End Focus Session")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Name (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Session name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Category")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Category", selection: $selectedCategoryID) {
                    ForEach(draft.categories) { category in
                        Text(category.name).tag(category.id)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.orbitSecondary)

                Spacer()

                Button("End Session") {
                    onConfirm(name, selectedCategoryID)
                }
                .buttonStyle(.orbitDestructive)
            }
        }
        .padding(18)
        .frame(width: 380)
        .background(.thinMaterial)
        .task {
            name = draft.name
            selectedCategoryID = draft.selectedCategoryID
        }
    }
}
