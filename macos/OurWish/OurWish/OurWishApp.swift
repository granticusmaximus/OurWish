import OurWishCore
import OurWishServer
import SwiftUI

@main
struct OurWishApp: App {
    @State private var authStore: AuthStore
    @State private var wishListStore: WishListStore
    @State private var collaborativeStore: CollaborativeStore

    private let shouldRunEmbeddedServer: Bool

    init() {
        if let remoteAPIBaseURL = AppRuntime.remoteAPIBaseURL {
            let api = RemoteOurWishAPI(baseURL: remoteAPIBaseURL)
            _authStore = State(initialValue: AuthStore(service: api))
            _wishListStore = State(initialValue: WishListStore(service: api))
            _collaborativeStore = State(initialValue: CollaborativeStore(service: api))
            shouldRunEmbeddedServer = false
        } else {
            _authStore = State(initialValue: AuthStore())
            _wishListStore = State(initialValue: WishListStore())
            _collaborativeStore = State(initialValue: CollaborativeStore())
            shouldRunEmbeddedServer = true
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authStore)
                .environment(wishListStore)
                .environment(collaborativeStore)
                .frame(minWidth: 980, minHeight: 640)
                .task {
                    guard shouldRunEmbeddedServer else { return }
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
