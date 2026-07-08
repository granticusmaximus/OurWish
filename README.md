# OurWish

A native macOS wish-list app, built with Swift, SwiftUI, and [GRDB.swift](https://github.com/groue/GRDB.swift) over a local SQLite database. No server, no network layer — everything runs on-device.

Originally a React + Express + Electron app; that stack has been fully replaced by the native app under `macos/OurWish/`.

## Project layout

- `macos/OurWish/OurWishCore/` — Swift Package containing the data layer: SQLite schema/migrations, password hashing, models, repositories, and `@Observable` stores. Has no UI dependencies, so it builds and its checks run with just Xcode Command Line Tools (`swift build`, `swift run SmokeTest`).
- `macos/OurWish/OurWish.xcodeproj` — the SwiftUI app target, generated from `macos/OurWish/project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen). Regenerate after editing `project.yml` with:
  ```
  cd macos/OurWish && xcodegen generate
  ```

## Data

The app reads and writes `~/Library/Application Support/OurWish/ourwish.db`, regardless of whether it's launched from Xcode (Debug) or run as an installed app (Release) — both use the exact same file, since the app runs without App Sandbox enabled. On first launch with an empty database, a default user and wish list are seeded automatically.

## Running

Requires the full Xcode app (not just Command Line Tools) to build and run the `OurWish` target. Open `macos/OurWish/OurWish.xcodeproj` and run the `OurWish` scheme.
