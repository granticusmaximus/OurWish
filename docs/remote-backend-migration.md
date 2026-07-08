# OurWish Remote Backend Migration

## Goal

Support one shared OurWish account/data set across:

- the native macOS app
- the React PWA
- a remotely hosted backend reachable from anywhere

## Current State

- The macOS app reads and writes SQLite directly through `AuthStore`, `WishListStore`, and `CollaborativeStore`.
- The React app talks to HTTP routes, but those routes currently live inside the macOS process.
- The server and core packages are still biased toward macOS-only runtime behavior.

## Target State

- A standalone backend process owns the source-of-truth database.
- The PWA points at that backend with a configurable API base URL.
- The macOS app stops treating local SQLite as the source of truth and instead talks to the backend through client abstractions.

## Runtime Configuration

- `OURWISH_API_BASE_URL`: switches the macOS app into remote mode. Point this at the hosted backend root, for example `https://wishlist.example.com`.
- `OURWISH_WEB_BASE_URL`: optional override for the URL copied from the macOS app's account menu. Defaults to `OURWISH_API_BASE_URL` when remote mode is enabled.

## Migration Phases

### Phase 1: Remote-ready backend foundation

- Make the web client accept a configurable API base URL.
- Decouple the server from “same-origin only” assumptions.
- Keep the existing REST contract stable.

### Phase 2: Native client abstraction seam

- Introduce service/client protocols for auth, wish lists, and collaborative lists.
- Preserve the current SwiftUI view layer while allowing local or remote backing implementations.

### Phase 3: Remote store implementations

- Add HTTP-backed implementations for the current store behaviors.
- Switch the macOS app to remote mode by configuration.

### Phase 4: Production backend hardening

- Replace in-memory auth/session storage with persistent server-side session storage.
- Add deploy configuration, environment handling, and containerization.
- Validate the backend against a centralized production database.

## Constraints

- The current local-first GRDB observation model in the macOS app does not map directly to a remote backend.
- The initial remote macOS mode should be online-first with explicit refresh after mutations.
- Offline sync should be treated as a later project, not part of the first backend extraction.
