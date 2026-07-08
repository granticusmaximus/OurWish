import OurWishCore
import OurWishServer
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
                .task {
                    // Runs for the lifetime of the app. A failure here (e.g. the port
                    // is already in use) is logged, not fatal — the native UI works
                    // fine regardless of whether the web server is reachable.
                    do {
                        try await WishServer().run()
                    } catch {
                        print("OurWish web server failed to start: \(error)")
                    }
                }
        }
        .windowResizability(.automatic)
        .defaultSize(width: 1180, height: 780)
    }
}
