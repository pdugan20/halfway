# Threat model

## Scope and protected assets

Halfway is a macOS 26+ menu bar app that scrobbles Apple Music to Last.fm.
Direct distribution uses a signed, notarized DMG and Sparkle; store distribution
is future scope (`README.md`, `project.yml`, `docs/automatic-updates.md`).
Protect session authority, listening history, account attribution, availability,
installed code, and release credentials. Scope covers the app and release tooling.

## Entry points

- Local apps supply distributed playback notifications and metadata
  (`Halfway/Sources/MusicObserver.swift`).
- Users initiate sign-in, sign-out, Love changes, sends, login registration, and
  updates (`Halfway/Sources/AccountRow.swift`, `Halfway/Sources/MenuContent.swift`,
  `Halfway/Sources/SettingsView.swift`, `Halfway/Sources/UpdateSettings.swift`).
- Last.fm supplies tokens, sessions, track state, errors, and results over HTTPS
  (`Halfway/Sources/LastFMClient.swift`).
- Local JSON, Keychain records, and preferences supply startup state
  (`Halfway/Sources/Storage.swift`, `Halfway/Sources/AppModel.swift`).
- Network feeds and archives enter Sparkle; metadata supplies browser links
  (`Halfway/Resources/Info.plist`, `Halfway/Sources/InlineUpdateDriver.swift`).
- Contributors supply pull requests; tag publishers and CI supply release inputs
  and dependencies (`.github/workflows/ci.yml`, `.github/workflows/release.yml`).

## Trust boundaries and assumptions

Validate notifications, disk records, API responses, and update metadata before
side effects. Notification names must not serve as account authorization
(`Halfway/Sources/MusicObserver.swift`, `Halfway/Sources/AppModel.swift`).
Browser approval and token exchange establish the session; its key authorizes
writes. Preserve cancellation and identity checks across asynchronous work
(`Halfway/Sources/LastFMClient.swift`, `HalfwayTests/AccountLifecycleTests.swift`).

Trust macOS to enforce Keychain access, App Sandbox, hardened runtime, and
installation authorization. Preserve outbound networking and the two app-scoped
Sparkle Mach lookup exceptions; review entitlement expansion
(`Halfway/Resources/Halfway.entitlements`, `project.yml`,
`docs/automatic-updates.md`). Sparkle verification and CI signing gate executable
replacement (`Halfway/Sources/AppUpdater.swift`, `.github/workflows/release.yml`).

## Sensitive data and privileged actions

Sessions contain a username and key. Pending JSON holds tracks, timestamps, and
account attribution; recent JSON retains ten outcomes. Treat retained history as
personal data after sign-out too (`Halfway/Sources/Storage.swift`).
Client-distributed build credentials must not be the sole authorization boundary
(`Config/Base.xcconfig`, `Halfway/Resources/Info.plist`,
`Halfway/Sources/AppModelServices.swift`).

Privileged actions include now-playing updates, scrobbles, Love changes, login
registration, app replacement, and publication. Confine signing and notarization
secrets to authorized releases (`Halfway/Sources/AppModel.swift`,
`.github/workflows/release.yml`).

## Principal threats and required controls

- Account confusion: bind plays and completions to their originating account;
  define legacy attribution and pause/sign-out effects on queued and in-flight
  work (`Halfway/Sources/AppModel.swift`, `Halfway/Sources/Storage.swift`).
- Forged or malformed input: bound metadata, dates, queues, responses, and work
  rate; validate finite numeric ranges before conversion. Preserve timing and
  duplicate suppression (`Halfway/Sources/MusicObserver.swift`,
  `Halfway/Sources/PlaybackTracker.swift`, `Halfway/Sources/LastFMClient.swift`).
- Disclosure: keep sessions in Keychain, handle persistence failures, minimize
  retention, and redact listening data and server errors in logs. Constrain HTTPS
  destinations and form encoding (`Halfway/Sources/Storage.swift`,
  `Halfway/Sources/AppModel.swift`, `Halfway/Sources/LastFMClient.swift`).
- Malicious updates: retain signed-feed and pre-extraction verification,
  checksum-verified tools, archive signatures, version checks, draft-first
  publication, and secret cleanup. Review dependencies as executable code
  (`Halfway/Resources/Info.plist`, `scripts/fetch-sparkle-tools`,
  `scripts/verify-update-feed.swift`, `scripts/publish-release`,
  `.github/workflows/release.yml`).

## Review priorities

Review release trust and secrets first, then account transitions and privacy,
then hostile-input parsing and persistence. Extend relevant coverage
(`HalfwayTests/`, `scripts/tests/test_release_workflow.py`, `scripts/check`).

## Uncertain assumptions

- Repository rules, tag permissions, CI secret access, and runner isolation need
  deployment confirmation (`.github/workflows/release.yml`).
- Last.fm token lifetime, revocation, retention, and retry semantics need service
  confirmation (`Halfway/Sources/LastFMClient.swift`, `Halfway/Sources/AppModel.swift`).
- Shipped signatures, nested helpers, and installation need artifact and runtime
  verification (`docs/release-checks.md`).
- Effective Keychain access, file protection, and backup/log retention depend on
  macOS and machine policy (`Halfway/Sources/Storage.swift`,
  `Halfway/Sources/MusicObserver.swift`).

## When to update this model

Update with changes to inputs, accounts, storage, destinations, dependencies,
entitlements, update keys, releases, or distribution (`AGENTS.md`, `project.yml`).
Revisit assumptions as evidence becomes available (`docs/release-checks.md`).
