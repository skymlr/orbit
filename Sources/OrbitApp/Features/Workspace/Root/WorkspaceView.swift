import ComposableArchitecture
import SwiftUI

struct WorkspaceView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>

    var body: some View {
        OrbitAdaptiveLayoutReader { layout in
            SessionPageView(store: store)
                .task {
                    store.send(.settingsRefreshTapped)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background {
                    OrbitSpaceBackground()
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    if layout.isCompact, let toast = store.toast {
                        OrbitToastView(
                            toast: toast,
                            onDismiss: {
                                store.send(.toastDismissTapped)
                            }
                        )
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .transition(.orbitToastNotification)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if !layout.isCompact, let toast = store.toast {
                        OrbitToastView(
                            toast: toast,
                            onDismiss: {
                                store.send(.toastDismissTapped)
                            }
                        )
                        .padding(.top, 14)
                        .padding(.trailing, 18)
                        .transition(.orbitToastNotification)
                    }
                }
                .animation(.easeInOut(duration: 0.24), value: store.toast?.id)
        }
    }
}
