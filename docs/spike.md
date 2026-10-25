# Spike: sandboxed Apple Music scrobbler

## Decision

Is a minimal, sandboxed menu bar app that only signs in to Last.fm and
scrobbles Apple Music plays reliable enough to replace NepTunes day to day, and
to ship as signed DMGs now and on the Mac App Store later?

## Unknowns

| Unknown | Kind | How the spike tests it |
| --- | --- | --- |
| A sandboxed app receives `com.apple.Music.playerInfo` with full track info | Hard blocker | Run the sandboxed Debug build, play library and streamed tracks, read the `music` log category |
| The notification includes a length (`Total Time`) for streamed Apple Music tracks | Scope modifier | Same log; if missing, Halfway falls back to the four-minute rule or needs a scripting-targets exception |
| Desktop auth, now playing and scrobbles work end to end with the registered key | Hard blocker | Sign in from the menu, play past the threshold, confirm on last.fm |
| Pause, skip, repeat-one and quitting Music produce one correct scrobble per listen | Scope modifier | Unit tests for the rules; manual pass with real playback |
| Music already playing when Halfway launches is picked up | Scope modifier | Launch Halfway mid-song; nothing is known until the next playback change |

## Version 1 scope

Sign in and out, now playing, scrobbles, offline queue, pause scrobbling, Open
at Login, quit, a first-launch welcome window, a Settings window (General and
Account), and an Icon Composer app icon.

## Scope decisions (2026-10-24)

| Item | Decision | Tracking |
| --- | --- | --- |
| Keep waiting scrobbles across sign-out | Built. Plays are tagged with their account and sent only to it; plays over 14 days old are dropped because Last.fm ignores them | — |
| Recent scrobbles in the menu | Built. Last 10 kept, 5 shown, with sent, waiting, ignored or rejected status | — |
| Love button | Built. Heart in the menu loves or unloves the current track; state comes from `track.getInfo` | — |
| Menu bar icon progress | Built. Ring fills in sixteenths toward the scrobble point | — |
| About link | Built. Settings › Account opens the standard About panel | — |
| Real playback test | Next, owner-run | [#1](https://github.com/pdugan20/halfway/issues/1) |
| Sync Apple Music favorites to Last.fm loves | After the playback test shows what Music reports | [#2](https://github.com/pdugan20/halfway/issues/2) |
| Fallback for missing streamed track length | Only if the playback test shows the gap | [#3](https://github.com/pdugan20/halfway/issues/3) |
| Sparkle auto-updates and first DMG release | With the release batch | [#4](https://github.com/pdugan20/halfway/issues/4) |
| Pick up a song already playing at launch | Deferred; needs Apple Events | [#5](https://github.com/pdugan20/halfway/issues/5) |
| Mac App Store build and listing | After the DMG release | [#6](https://github.com/pdugan20/halfway/issues/6) |
| Listening stats | Won't build; Last.fm already does this | — |
| Players other than Apple Music | Won't build; keeps Halfway an Apple Music tool | — |

## Evidence so far

- Last.fm key and secret produce valid signed requests (`auth.getToken` succeeds).
- Debug build is sandboxed with `network.client` only; builds clean under Swift 6
  strict concurrency on Xcode 27.1 / macOS 27.
- 13 unit tests cover the scrobble rules, request signing, form encoding, and
  notification parsing.

## Still to observe

- Real `playerInfo` payloads in the sandbox for library and streamed tracks.
- Sign-in and scrobbles against the owner's account.
- Behaviour of repeat-one and launch mid-song.

## Disposition

Salvageable. The code is written to be kept if the spike continues.
