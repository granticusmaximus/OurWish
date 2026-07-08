import OurWishCore
import SwiftUI

/// Replaces the top-level `view === 'login' / 'register' / …` branching in `App.tsx`.
struct RootView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(WishListStore.self) private var wishListStore
    @Environment(CollaborativeStore.self) private var collaborativeStore

    @State private var showRegister = false

    var body: some View {
        Group {
            if showRegister {
                RegisterView(onBack: { showRegister = false })
            } else if authStore.currentUser != nil {
                MainWindowView(onCreateNewUser: { showRegister = true })
            } else {
                LoginView()
            }
        }
        .onChange(of: authStore.currentUser?.id, initial: true) { _, newUserId in
            wishListStore.setCurrentUser(newUserId)
            collaborativeStore.setCurrentUser(newUserId)
        }
    }
}
