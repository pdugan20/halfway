"""Selected white / curved-arrow / lime-notch artwork. Used by dmgbuild 1.6.7."""

from pathlib import Path
import subprocess

app = Path(defines["app"]).resolve()
artwork = Path(defines["artwork"]).resolve()

format = "UDZO"
filesystem = "HFS+"
files = [(str(app), "Halfway.app")]
symlinks = {"Applications": "/Applications"}
# SetFile's extension-hiding flag adds FinderInfo to the signed app bundle and
# makes strict signature verification fail. Let Finder handle app extensions.
hide_extensions = []
background = str(artwork)
window_rect = ((160, 180), (760, 480))
default_view = "icon-view"
show_toolbar = False
show_sidebar = False
show_status_bar = False
show_pathbar = False
show_tab_view = False
include_icon_view_settings = True
arrange_by = None
icon_size = 128
text_size = 14
label_pos = "bottom"
show_icon_preview = True
icon_locations = {"Halfway.app": (201, 235), "Applications": (559, 235)}

app_icon = app / "Contents" / "Resources" / "AppIcon.icns"
if app_icon.is_file():
    icon = str(app_icon)


def create_hook(mount_point, _options):
    """Verify the packaged copy before dmgbuild seals the image."""
    subprocess.run(
        ["/usr/bin/codesign", "--verify", "--strict", str(Path(mount_point) / "Halfway.app")],
        check=True,
    )
