import AppKit
import Foundation
import OurWishCore
import OurWishServer
import SwiftUI

/// Replaces the `<Navbar>` + `<Container>` shell in `App.tsx` with a native macOS
/// sidebar layout (the pattern Mail/Notes/Reminders use) — a persistent list of every
/// wish list and collaborative list on the left, selected list's items on the right,
/// instead of a web-style top nav bar toggling between two full-page views.
struct MainWindowView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(WishListStore.self) private var wishListStore
    @Environment(CollaborativeStore.self) private var collaborativeStore
    var onCreateNewUser: () -> Void

    @State private var activeSection: SidebarSection = .wishLists
    @State private var showCreateWishList = false
    @State private var showCreateCollaborativeList = false
    @State private var showProfile = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showCreateWishList = true
                    } label: {
                        Label("New Wish List", systemImage: "gift")
                    }
                    Button {
                        collaborativeStore.refreshPartners()
                        showCreateCollaborativeList = true
                    } label: {
                        Label("New Collaborative List", systemImage: "person.2")
                    }
                } label: {
                    Label("New List", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Edit Profile…") { showProfile = true }
                    Button("Create New User…", action: onCreateNewUser)
                    Divider()
                    Button("Copy Web Access Link") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(webAccessURL, forType: .string)
                    }
                    Text("Open \(webAccessURL) on your phone or another computer on this WiFi network")
                    Divider()
                    Button("Log Out", role: .destructive) { authStore.logout() }
                } label: {
                    AccountMenuLabel(user: authStore.currentUser)
                }
            }
        }
        .sheet(isPresented: $showCreateWishList) {
            CreateWishListSheet { name in
                try wishListStore.createList(name: name)
                activeSection = .wishLists
            }
        }
        .sheet(isPresented: $showCreateCollaborativeList) {
            CreateCollaborativeListSheet(partners: collaborativeStore.partners) { email, name in
                try collaborativeStore.createList(partnerEmail: email, name: name)
                activeSection = .collaborative
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
    }

    /// Best-effort LAN URL for the companion web app. `hostName` typically looks like
    /// `Grants-MacBook-Pro.local`, resolvable by other devices on the same network via
    /// Bonjour/mDNS without needing to know the Mac's IP address.
    private var webAccessURL: String {
        "http://\(ProcessInfo.processInfo.hostName):\(WishServer.defaultPort)"
    }

    private var selectionBinding: Binding<SidebarSelection?> {
        Binding<SidebarSelection?>(
            get: {
                switch activeSection {
                case .wishLists:
                    return wishListStore.selectedListId.map { .wishList($0) }
                case .collaborative:
                    return collaborativeStore.selectedListId.map { .collaborative($0) }
                }
            },
            set: { newValue in
                switch newValue {
                case .wishList(let id):
                    activeSection = .wishLists
                    wishListStore.selectedListId = id
                case .collaborative(let id):
                    activeSection = .collaborative
                    collaborativeStore.selectedListId = id
                case nil:
                    break
                }
            }
        )
    }

    private var sidebar: some View {
        List(selection: selectionBinding) {
            Section("My Wish Lists") {
                if wishListStore.wishLists.isEmpty {
                    Text("No wish lists yet")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ForEach(wishListStore.wishLists) { list in
                    Label(list.name, systemImage: "gift.fill")
                        .tag(SidebarSelection.wishList(list.id!))
                }
            }

            Section("Collaborative Lists") {
                if collaborativeStore.lists.isEmpty {
                    Text("No collaborative lists yet")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ForEach(collaborativeStore.lists) { list in
                    Label(list.name, systemImage: "person.2.fill")
                        .tag(SidebarSelection.collaborative(list.id))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
    }

    @ViewBuilder
    private var detail: some View {
        switch activeSection {
        case .wishLists:
            if let id = wishListStore.selectedListId,
               let list = wishListStore.wishLists.first(where: { $0.id == id }) {
                WishListDetailView(list: list)
            } else {
                ContentUnavailableView(
                    "No Wish List Selected",
                    systemImage: "gift",
                    description: Text("Create a wish list to start adding items.")
                )
            }
        case .collaborative:
            if let id = collaborativeStore.selectedListId,
               let list = collaborativeStore.lists.first(where: { $0.id == id }) {
                CollaborativeDetailView(list: list)
            } else {
                ContentUnavailableView(
                    "No Collaborative List Selected",
                    systemImage: "person.2",
                    description: Text("Create a collaborative list to share with your partner.")
                )
            }
        }
    }
}

/// The account menu's toolbar label — shows the user's profile photo as a small
/// circular thumbnail when they've set one, falling back to a generic SF Symbol.
private struct AccountMenuLabel: View {
    let user: User?

    var body: some View {
        HStack(spacing: 6) {
            if let data = user?.profileImageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
            }
            Text(user?.displayName ?? "Account")
        }
    }
}
