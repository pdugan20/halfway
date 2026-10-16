# Halfway

macOS menu bar app (SwiftUI `MenuBarExtra`) that scrobbles Apple Music plays to Last.fm.

## Work modes

- Default to exploration for design iterations, prototypes, and small changes. Make focused edits directly; do not
  require a formal spec, separate plan, worktree, or TDD.
- Apply production rigor when the user explicitly asks to ship, harden, prepare a release, or use strict TDD.
- Ask before releases (pushing `v*` tags), changing GitHub secrets, or anything that posts to a real Last.fm account
  other than the owner's manual testing.

## Project

- `project.yml` (XcodeGen) owns the Xcode project. Run `xcodegen generate` after adding, moving, or removing files.
  Never commit `Halfway.xcodeproj`.
- Last.fm credentials live in git-ignored `Config/Secrets.xcconfig` and reach the app through `Info.plist`
  (`LastFMAPIKey`, `LastFMAPISecret`). Never commit them, print them, or put them in tests or logs.
- One verification command: `scripts/check`.
- Use a bounded DerivedData path such as `~/DerivedData/halfway-slot-0`.

## Architecture

- `MusicObserver` — subscribes to the `com.apple.Music.playerInfo` distributed notification and parses it.
- `PlaybackTracker` — pure scrobble rules (over 30 s; half length or 4 min; paused time excluded; repeat detection).
  Keep it free of I/O; it is the most heavily tested code.
- `LastFMClient` — desktop auth (`auth.getToken` → browser approval → `auth.getSession`), `track.updateNowPlaying`,
  `track.scrobble` (≤ 50 per request), MD5 request signing.
- `Storage` — session key in the keychain; pending scrobbles in Application Support (sandbox container).
- `AppModel` — `@Observable` glue: schedules ticks at the next scrobble deadline, flushes the queue, retries.
- `MenuContent` — the `.window`-style menu bar panel.

## Constraints

- Stay App Sandbox compatible (future Mac App Store release). Entitlements: `app-sandbox`, `network.client` only.
  Adding Apple Events or a scripting-targets exception needs a stated reason.
- Do not use private frameworks (e.g. MediaRemote).
- Swift 6 with `MainActor` default isolation; mark pure model types `nonisolated`.

## Code style

Airbnb Swift style via SwiftFormat and SwiftLint (`.swiftformat`, `.swiftlint.yml` → `.swiftlint-airbnb.yml`).
2-space indentation, 120-column warning.

## Release

Tag `vX.Y.Z` to run `.github/workflows/release.yml`: Developer ID signing, notarization, DMG, GitHub Release.
Required secrets: `DEVELOPER_ID_CERT_BASE64`, `DEVELOPER_ID_CERT_PASSWORD`, `NOTARY_API_KEY`, `NOTARY_API_KEY_ID`,
`NOTARY_API_ISSUER`, `LASTFM_API_KEY`, `LASTFM_API_SECRET`.

## Code review rules

- Flag scrobble-rule changes in `PlaybackTracker` that lack a matching test.
- Flag any path that could log, persist outside the keychain, or commit the Last.fm secret or session key.
- Flag new entitlements, Apple Events use, or private API use.
