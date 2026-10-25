# DMG design exploration

## Selected local DMG

Option 1 from the notch studies is packaged by `scripts/build-dmg`: a white background,
curved charcoal arrow, lime corner ticks, and real Halfway / Applications Finder items. There is no
headline or footer. `packaging/dmg/settings.py` owns its 760 × 480-point Finder window, 128-point
icons, and placement. `packaging/dmg/background.tiff` contains 1× and 2× representations of the
selected `notch-classic-drag-background@2x.png` export from the workbench.

Run `scripts/check` to refresh and verify the app, then `scripts/build-dmg`. The script accepts
an optional app path and output path. Its default artifact is `build/dmg/Halfway-local-preview.dmg`.
It installs the pinned dependencies from `packaging/dmg/requirements.txt` in the ignored
`build/dmg-tools` virtual environment if needed. dmgbuild
uses `ditto` to copy the app and writes Finder layout data without Finder automation.

The default output is for local owner testing: the app retains its development signature, and the
DMG is not notarized or signed for public distribution. The script verifies the input app and the
packaged copy's signatures, plus the disk-image checksum. It never launches Halfway or copies it
into Applications. The release workflow calls the same script with its Developer ID-signed app,
then signs, notarizes, and staples the DMG before publishing it.

To regenerate the TIFF after editing the selected design, export the current set from the native
workbench, convert the selected background to 760 × 480 at 72 dpi and 1520 × 960 at 144 dpi with
`sips`, then combine them with `tiffutil -cathidpicheck`.

## Design workbench

Run `scripts/dmg-preview/run` from the repository. This builds a small native SwiftUI workbench in
the ignored `build/dmg-preview` directory. It does not launch Halfway, load account data, or install
anything. Compare designs with the segmented control; switch the installation flow and Finder
chrome independently. The current set contains four white-background notch studies: Classic ticks,
Small ticks, Brush + ticks, and Destination ticks. They omit headline and footer text and keep only
the file labels. Use the Studies menu to revisit the six earlier minimalist variations and the
two original sets. Keyboard shortcuts: 1–6 for the visible designs, I for installation flow,
D for chrome.

The comparison holds the 760 × 480-point content area, current Icon Composer artwork, file labels,
and installation flow constant. The current notch set uses the same 128-point icons, placement,
white background, and file labels; its variables are the size and placement of lime ticks and
curved versus brush arrow. The previous minimalist set also uses the same 128-point icons and the
same icon placement. Its intentional variables are arrow weight, title visibility, instruction
visibility, a few quiet grooves, and white versus warm paper. White brush and Paper brush omit
instruction text to compare the spare Notion-like composition; the other four keep a small instruction.
The previous set also holds icon size and placement constant: Drawn minimal has a curved drawn
arrow and lime accents; Soft sleeve adds a restrained record rim on warm paper; Illustrated margins
places original music drawings around a clear installation area.
The earlier Paper sleeve uses editorial type and faint record grooves; Quiet utility emphasizes
the instruction and icon; Listening room separates brand artwork from the installation area.
Each supports both installation-flow concepts.

Export 2× PNGs with `scripts/dmg-preview/run --export /absolute/output/directory`, or export just
the latest set with `--export-current /absolute/output/directory`. The exporter uses
the same SwiftUI views as the workbench and also exports background-only artwork. These are design
previews with illustrated Finder chrome and file labels, not screenshots of mounted disk images.
All background-only exports omit file icons and labels. The current studies retain the drawn arrow
as background art for drag layouts so packaging can position real Finder items over it. The earlier
studies omit the arrow too; restore it to the background if choosing one of those for packaging.

## Installation behavior

A DMG is a container. A single icon with a double-click instruction requires an installer, an
installer package, or deliberately implemented first-launch relocation. Opening an ordinary app
from a mounted image does not itself copy the app to Applications. Halfway currently ships a
plain app plus an Applications symlink. Its sandbox has no general permission to write to
Applications, so copying a self-relocation snippet into the app is not a complete implementation.

Dropbox documents an installer workflow. Ghostty documents dragging its app into Applications.
Granola's supplied screenshot shows an Install Granola item, but does not establish its internal
mechanism; its current Homebrew cask installs a Granola.app bundle. Both visual conventions remain
in use. Neither is a universal modern macOS requirement.

For Halfway's existing architecture, a restrained drag layout is the smallest functional change.
If a single-icon design is selected, evaluate a signed installer package or separate installer
before using double-click installation copy. Keep the main app sandboxed.

## Packaging guidance for the selected design

- Use one explicit action, short instructions, generous whitespace, and the actual app icon.
- Place real Finder items over static artwork; do not bake clickable-looking buttons into it.
- Use a background that supports legible Finder labels in both appearances. Custom DMG backgrounds
  do not automatically become the app's dark appearance. The workbench's chrome toggle illustrates
  the fixed artwork; actual Finder label contrast still needs verification on a mounted image.
- Export Retina artwork and configure Finder icon view, window size, positions, and hidden
  background files. `dmgbuild` exposes these settings without scripting Finder.
- Sign the app and DMG with Developer ID, notarize the outer distribution container, and staple
  the ticket. Test clean install, replacement, duplicates, and launch directly from the image on
  a clean Mac or VM. Avoid requiring elevated privileges for a simple app copy when unnecessary.

The release workflow is unchanged. These previews do not implement an installer or change launch
behavior. After selection, remove abandoned designs and preview controls when graduating the chosen
artwork into packaging. Keep or archive the workbench as design evidence; no temporary checkout exists.

Sources checked 2026-10-25:

- [Apple: Packaging Mac software](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)
- [Apple: Accessing files from the App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)
- [Dropbox installation instructions](https://help.dropbox.com/installs/download-dropbox)
- [Ghostty macOS installation](https://ghostty.org/docs/install/binary)
- [Granola's Homebrew cask](https://github.com/Homebrew/homebrew-cask/blob/master/Casks/g/granola.rb)
- [dmgbuild settings](https://dmgbuild.readthedocs.io/en/latest/settings.html)
