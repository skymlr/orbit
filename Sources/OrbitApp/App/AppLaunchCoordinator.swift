import ComposableArchitecture
import SwiftUI

struct AppLaunchCoordinator: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task {
                store.send(.onLaunch)
            }
    }
}
