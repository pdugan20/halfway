# Release checks

The first release is the baseline for testing installation and a real update. The 0.1.1
follow-up updates the public installation instructions and version metadata; it keeps the
same app behavior and artwork.

## Install and update

1. Quit any development copy of Halfway. Download the
   [0.1.0 DMG](https://github.com/pdugan20/halfway/releases/download/v0.1.0/Halfway-v0.1.0.dmg)
   through your browser. For a clean Gatekeeper check, use a separate macOS user account.
2. Open the DMG and check the white background, curved arrow, lime notches, and native app
   and Applications icons. Drag Halfway to Applications and launch it.
3. Halfway should run in the menu bar. Check the drawn h in light and dark mode and confirm
   there is no persistent Dock icon.
4. Leave **Keep Halfway up to date** enabled. Once 0.1.1 is published, it should download in
   the background and show **Update and Relaunch** inside the existing panel. Other apps
   should keep focus and no separate update window should appear.
5. Choose **Update and Relaunch** and check that Settings → Account shows version 0.1.1.
   In Settings → General, **Check for Updates** should show its result inline.
6. To exercise installation on quit separately, quit Halfway, reinstall the 0.1.0 baseline,
   launch it, wait for the ready update, and choose **Quit Halfway**. On the next launch,
   the version should be 0.1.1. Quitting should not reopen the app automatically.

## Real Music and Last.fm

These checks intentionally use the owner's manual testing, not automated posts to a real account.

1. Sign in with Last.fm. Start a song in Music after launching Halfway. Picking up a song
   that was already playing at launch is tracked separately in
   [GitHub issue #5](https://github.com/pdugan20/halfway/issues/5).
2. Check the countdown and progress icon, pause/resume, and verify one scrobble appears
   after half the track or four minutes, whichever comes first. Tracks under 30 seconds
   should not scrobble.
3. Toggle Love, wait for completion, and verify the state on Last.fm. The control should
   prevent overlapping writes.
4. Test Open at Login and confirm the app returns to the menu bar after signing in to macOS.

Automated release verification checks notarization tickets, Developer ID signatures (including
Sparkle helpers), the packaged artwork, and the hosted feed and DMG signatures. It cannot replace
a browser download and first launch on a clean account or the owner's actual playback check.
