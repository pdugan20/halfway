#!/usr/bin/env python3
"""Fast release contract checks without reading credentials or starting the app."""
import base64
import json
from pathlib import Path
import plistlib
import re

root = Path(__file__).resolve().parent.parent
manifest = json.loads((root / "packaging/sparkle/tools.json").read_text())
project = (root / "project.yml").read_text()
assert f'exactVersion: {manifest["version"]}' in project, "Sparkle app/tools versions differ"
assert re.fullmatch(r"[a-f0-9]{64}", manifest["sha256"]), "Invalid Sparkle tool checksum"
assert manifest["url"] == (
    f'https://github.com/sparkle-project/Sparkle/releases/download/{manifest["version"]}/'
    f'Sparkle-{manifest["version"]}.tar.xz'
), "Unexpected Sparkle distribution URL"
with (root / "Halfway/Resources/Info.plist").open("rb") as file:
    info = plistlib.load(file)
assert info["SUFeedURL"] == "https://github.com/pdugan20/halfway/releases/latest/download/appcast.xml"
assert len(base64.b64decode(info["SUPublicEDKey"], validate=True)) == 32, "Invalid Ed25519 public key"
for key in ("LSUIElement", "SUEnableInstallerLauncherService", "SUEnableAutomaticChecks",
            "SUAutomaticallyUpdate", "SUVerifyUpdateBeforeExtraction", "SURequireSignedFeed"):
    assert info.get(key) is True, f"{key} must be enabled"
assert info.get("SUEnableSystemProfiling") is False
assert not info.get("SUEnableDownloaderService", False), "App already has network.client"
with (root / "Halfway/Resources/Halfway.entitlements").open("rb") as file:
    entitlements = plistlib.load(file)
assert set(entitlements) == {
    "com.apple.security.app-sandbox", "com.apple.security.network.client",
    "com.apple.security.temporary-exception.mach-lookup.global-name",
}, "Review changed entitlements"
assert entitlements["com.apple.security.app-sandbox"] is True
assert entitlements["com.apple.security.network.client"] is True
assert entitlements["com.apple.security.temporary-exception.mach-lookup.global-name"] == [
    "$(PRODUCT_BUNDLE_IDENTIFIER)-spks", "$(PRODUCT_BUNDLE_IDENTIFIER)-spki",
]
print("Release configuration contracts passed")
