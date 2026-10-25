# Automatic updates

Halfway uses Sparkle 2.10.1 for its directly distributed build. It remains a sandboxed,
menu-bar-only app. Debug builds never start the updater or contact its feed.

## Interaction

- Automatic checks and downloads run quietly. No update windows, notifications, Dock badges,
  or focus changes are created by Halfway's update UI.
- A prepared update adds an inline **Update and Relaunch** action to the existing panel and Settings.
  Sparkle also installs it when Halfway quits. It never restarts Halfway automatically while it is running.
- Settings has one **Keep Halfway up to date** toggle, enabled by default, and **Check for Updates**.
  Manual checks show their progress, current-version result, or Retry in the same surface.
- Turning the toggle off stops future automatic checks and downloads. An update already prepared
  for installation can still install on quit.
- Background errors do not interrupt listening; Sparkle schedules later attempts. Manual failures stay inline.
- macOS can require installation authorization if the installed app is owned by another user.
  A custom Sparkle user driver cannot suppress this system authorization.

`AppUpdater` owns Sparkle's core updater and preferences. `InlineUpdateDriver` implements
Sparkle's UI protocol without its standard windows. Both the panel and Settings render
`UpdateStatusRow`. The install-on-quit delegate retains the immediate-install handler and
returns control to the inline UI, preventing Sparkle's eventual reminder for a long-running app.
User callbacks are cleared after use or dismissal so stale actions cannot trigger installation.

The sandbox's two additional Mach lookup exceptions are limited to this app's `-spks` and
`-spki` installer/status services. They are required by Sparkle's sandbox integration; the
existing network client entitlement handles downloads. No Apple Events or file access permissions
are added. A future Mac App Store distribution should omit Sparkle and these exceptions and
use store-managed updates.

## Release pipeline

A stable `vX.Y.Z` tag triggers `.github/workflows/release.yml`:

1. Fetch the pinned Sparkle tools and verify their SHA-256 checksum.
2. Archive a universal app (Apple silicon and Intel), then export for Developer ID distribution.
   Export re-signs Sparkle's nested helper tools and XPC services, not just its outer framework.
3. Notarize and staple the app.
4. Package the selected white / drawn-arrow / lime-notch DMG, sign it, then notarize and staple it.
5. Generate an Ed25519-signed appcast and sign the final DMG bytes. Verify both signatures against
   the public key in the exported app, and check versions, download URL, and byte count.
6. Upload the DMG and `appcast.xml` to a draft GitHub Release, then publish it. Failed drafts can
   resume. Older or already published versions cannot replace the current feed or its assets.

The app reads `https://github.com/pdugan20/halfway/releases/latest/download/appcast.xml`.
Each enclosure points to an immutable versioned release asset. The feed currently contains
one full universal update, with no delta patches. Before raising the minimum macOS version or
removing an architecture, preserve an older compatible branch in the feed and adapt its verifier.

Only the public update key is in the app. The dedicated private key is in the maintainer's
login Keychain under account `com.patrickdugan.halfway`. CI requires **SPARKLE_PRIVATE_KEY** in
addition to the existing Developer ID, notarization, and Last.fm secrets. A missing key stops
release publication; a mismatched key fails verification. Do not regenerate or replace this key
casually: installed copies trust the embedded public key.

Adding a GitHub secret and pushing a release tag require separate owner approval. No release
is published merely by building, testing, or committing these files. The first build containing
Sparkle still needs a manual install; older copies cannot acquire an updater retroactively.

## Verification

`scripts/check` includes release configuration contracts, publication tests with a fake GitHub
CLI, workflow lint, Swift format/lint, and the app tests. Update-driver tests cover manual vs
background errors, cancellation, bounded progress, explicit installation, fresh-install defaults,
and unsupported macOS versions without starting a real updater or using a Last.fm account.

Local packaging and signed-feed checks can use a built app and the Keychain account:

```bash
scripts/fetch-sparkle-tools
scripts/build-dmg /path/to/Halfway.app "$PWD/build/release/Halfway-vX.Y.Z.dmg"
scripts/generate-update-feed "$PWD/build/release" vX.Y.Z
swift scripts/verify-update-feed.swift build/release/appcast.xml \
  build/release/Halfway-vX.Y.Z.dmg /path/to/Halfway.app/Contents/Info.plist vX.Y.Z BUILD_NUMBER
```

The app version and build number must match those arguments. A development-signed DMG is only
local verification evidence, not a notarized release. Do not modify the DMG after signing the feed.

References: [Sparkle UI protocol](https://sparkle-project.org/documentation/api-reference/Protocols/SPUUserDriver.html),
[automatic update defaults](https://sparkle-project.org/documentation/customization/),
[sandbox integration and signing](https://sparkle-project.org/documentation/sandboxing/),
[publishing updates](https://sparkle-project.org/documentation/publishing/).
