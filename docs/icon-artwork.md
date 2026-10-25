# Icon artwork

The drawn h in `Halfway/Resources/AppIcon.icon/Assets/halfway-mark.svg` is the editable source artwork.
It is a single filled vector path on a transparent 1024 × 1024 canvas, reconstructed from the selected
soft tonal concept. Edit its curves in a vector editor; keep the background and outer icon mask out of this SVG.

## App icon

Open `Halfway/Resources/AppIcon.icon` in Apple's Icon Composer. Its `icon.json` owns the lime gradient,
charcoal mark, and explicit dark appearance with a pale mark on olive. The h uses a flat material; the
system supplies the tile's rounded mask and lighting. Appearance overrides include their base value in
the `fill-specializations` array; a separate `fill` property takes precedence over that array.

`project.yml` already includes this package as `AppIcon`. Xcode compiles the system app icon for Finder,
the welcome window, installation, and any Dock presentation. Halfway remains menu-bar-only through
`LSUIElement`; changing the artwork does not enable a persistent Dock icon.

Apple's bundled renderer can export actual appearance previews. Confirm its supported flags with `--help`
after changing Xcode versions:

```sh
"$(dirname "$(xcode-select -p)")/Applications/Icon Composer.app/Contents/Executables/ictool" \
  Halfway/Resources/AppIcon.icon \
  --export-image --output-file /tmp/halfway-dark.png \
  --platform macOS --rendition Dark --width 512 --height 512 --scale 1 --design-generation 26
```

Review Default, Dark, TintedLight, TintedDark, ClearLight, and ClearDark, including the minimum supported
macOS 26 rendering. Check actual small sizes as well as large previews.

## Menu bar

`Assets.xcassets/MenuBarMark.imageset/halfway-mark.pdf` is a derived vector PDF of the same SVG. The asset
catalog preserves its vector representation and marks it as a template. `MenuBarIcon` renders it onto
an 18-point canvas: solid when idle or scrobbled, subdued when inactive, and filling from the bottom
as playback approaches the scrobble threshold. macOS supplies the template colour for the current
menu bar appearance and selection state. Scrobble timing rules remain in `PlaybackTracker`.

After editing the SVG, regenerate the PDF from the repository root with `rsvg-convert` (from Homebrew's
`librsvg` package):

```sh
rsvg-convert --format pdf --width 18pt --height 18pt \
  --output Halfway/Resources/Assets.xcassets/MenuBarMark.imageset/halfway-mark.pdf \
  Halfway/Resources/AppIcon.icon/Assets/halfway-mark.svg
```

The converter is only needed to update artwork; normal Xcode builds consume the checked-in SVG and PDF.
Run `xcodegen generate` after adding or removing assets, then `scripts/check`.

References: [Apple's Icon Composer workflow](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)
and [NSImage template images](https://developer.apple.com/documentation/appkit/nsimage/istemplate).
