#!/usr/bin/env bash
# Pinned upstream release assets; verify before extracting or executing.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != Darwin ]]; then
  echo "CI tools require macOS" >&2
  exit 1
fi
case "$(uname -m)" in
  arm64)
    actionlint_arch=arm64
    actionlint_sha=aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f
    ;;
  x86_64)
    actionlint_arch=amd64
    actionlint_sha=5b44c3bc2255115c9b69e30efc0fecdf498fdb63c5d58e17084fd5f16324c644
    ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

prefix="$PWD/build/ci-tools"
mkdir -p "$prefix/bin"
work=$(mktemp -d "$prefix/download.XXXXXX")
trap 'rm -rf "$work"' EXIT

fetch() {
  local name=$1 url=$2 sha=$3
  curl --fail --location --retry 3 --silent --show-error "$url" -o "$work/$name"
  printf '%s  %s\n' "$sha" "$work/$name" | shasum -a 256 -c -
}

# XcodeGen 2.46.0 includes runtime SettingPresets alongside its binary.
fetch xcodegen.zip https://github.com/yonaskolb/XcodeGen/releases/download/2.46.0/xcodegen.zip \
  4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806
unzip -q "$work/xcodegen.zip" -d "$work/xcodegen"
cp -R "$work/xcodegen/xcodegen/share" "$prefix/"
install -m 755 "$work/xcodegen/xcodegen/bin/xcodegen" "$prefix/bin/xcodegen"

# SwiftLint 0.65.1
fetch swiftlint.zip https://github.com/realm/SwiftLint/releases/download/0.65.1/portable_swiftlint.zip \
  c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0
unzip -q "$work/swiftlint.zip" -d "$work/swiftlint"
install -m 755 "$work/swiftlint/swiftlint" "$prefix/bin/swiftlint"

# SwiftFormat 0.64.5
fetch swiftformat.zip https://github.com/nicklockwood/SwiftFormat/releases/download/0.64.5/swiftformat.zip \
  ec017c91fdd46233e5a22dc43ff9564a3cc4b37023d3b4681b6c7d7b781de113
unzip -q "$work/swiftformat.zip" -d "$work/swiftformat"
install -m 755 "$work/swiftformat/swiftformat" "$prefix/bin/swiftformat"

# xcbeautify 3.2.1 (universal macOS binary)
fetch xcbeautify.zip https://github.com/cpisciotta/xcbeautify/releases/download/3.2.1/xcbeautify-3.2.1-universal-apple-macosx.zip \
  87fdbe786f71d7b2ee28c5c1ca97087587292f2c5c6f9e721cf02db8b2a3c241
unzip -q "$work/xcbeautify.zip" -d "$work/xcbeautify"
install -m 755 "$work/xcbeautify/release/xcbeautify" "$prefix/bin/xcbeautify"

# actionlint 1.7.12
fetch actionlint.tar.gz \
  "https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_darwin_${actionlint_arch}.tar.gz" \
  "$actionlint_sha"
tar -xzf "$work/actionlint.tar.gz" -C "$work" actionlint
install -m 755 "$work/actionlint" "$prefix/bin/actionlint"

if [[ -n "${GITHUB_PATH:-}" ]]; then
  printf '%s\n' "$prefix/bin" >> "$GITHUB_PATH"
fi
echo "Installed pinned CI tools in $prefix/bin"
