import SwiftUI

extension View {
    func orbitPhoneListStyle() -> some View {
        self
            .listStyle(.plain)
    }

    func orbitPhoneListRow(insets: EdgeInsets) -> some View {
        self
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(insets)
    }
}
