# Halfway

Halfway is a tiny macOS menu bar app that scrobbles what you play in Apple
Music to [Last.fm](https://www.last.fm). Sign in once and it does the rest.

It is named after Last.fm's rule: a song counts once you've heard half of it,
or four minutes, whichever comes first.

> Status: early spike. Not yet released.

## Features

- Sign in with Last.fm through your browser
- Now playing updates and scrobbles for Apple Music, including streamed tracks
- Offline queue that sends waiting scrobbles when you're back online
- Pause scrobbling and Open at Login from the menu

Halfway runs in the App Sandbox and needs no Automation permission. It listens
to the playback notification Music already broadcasts.

## Requirements

macOS 26 or newer. Development needs Xcode 26 or newer and Homebrew.

## Development

```bash
brew bundle                                         # XcodeGen, SwiftLint, SwiftFormat, pre-commit
pre-commit install
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # add your Last.fm API key and secret
xcodegen generate                                   # creates Halfway.xcodeproj
open Halfway.xcodeproj
```

`project.yml` is the source of truth for the Xcode project; the generated
`Halfway.xcodeproj` is not committed. Get Last.fm credentials at
[last.fm/api/account/create](https://www.last.fm/api/account/create).

Run every check (format, lint, build, tests):

```bash
scripts/check
```

Watch what Music reports and what Halfway decides:

```bash
/usr/bin/log stream --style compact --level info --predicate 'subsystem == "com.patrickdugan.halfway"'
```

## License

MIT
