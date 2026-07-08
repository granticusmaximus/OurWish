import OurWishCore
import SwiftUI

@main
struct OurWishApp: App {
    @State private var authStore = AuthStore()
    @State private var wishListStore = WishListStore()
    @State private var collaborativeStore = CollaborativeStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authStore)
                .environment(wishListStore)
                .environment(collaborativeStore)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowResizability(.automatic)
        .defaultSize(width: 1180, height: 780)
    }
}
