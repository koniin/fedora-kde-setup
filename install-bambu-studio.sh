#!/bin/bash
# Install Bambu Studio from Bambu Lab's official AppImage (not Flatpak), or
# update it if GitHub has a newer release. Does nothing if the newest release
# is already installed.
#
# Fedora has no Bambu Studio package and Bambu Lab no longer builds a Fedora
# AppImage, so this uses their Ubuntu 24.04 AppImage. It is unpacked into
# ~/.local/opt/bambu-studio (so it doesn't need FUSE and starts faster), with a
# `bambu-studio` launcher in ~/.local/bin and an app menu entry that also opens
# .3mf/.stl files and MakerWorld's "Open in Bambu Studio" links.
#
# The download is checked against the SHA-256 that GitHub lists for it.
# Your settings in ~/.config/BambuStudio are never touched.

set -euo pipefail

REPO="bambulab/BambuStudio"
INSTALL_DIR="$HOME/.local/opt/bambu-studio"
BIN="$HOME/.local/bin/bambu-studio"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICON_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/256x256/apps"
DESKTOP_FILE="$APPS_DIR/bambu-studio.desktop"
VERSION_FILE="$INSTALL_DIR/.version"

if [[ $(uname -m) != x86_64 ]]; then
  echo "Bambu Studio's Linux build only exists for x86_64." >&2
  exit 1
fi

if flatpak info com.bambulab.BambuStudio >/dev/null 2>&1; then
  echo "Note: the Flatpak Bambu Studio is also installed. You may want to remove it:"
  echo "  flatpak uninstall com.bambulab.BambuStudio"
fi

echo "Checking the latest Bambu Studio release..."
release=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest")
read -r tag url digest < <(python3 -I -c '
import json, sys
d = json.load(sys.stdin)
for a in d["assets"]:
    n = a["name"]
    if "ubu24" in n and n.endswith(".AppImage"):
        print(d["tag_name"], a["browser_download_url"], (a.get("digest") or "").removeprefix("sha256:"))
        break
' <<<"$release")

if [[ -z ${url:-} ]]; then
  echo "Couldn't find an Ubuntu 24.04 AppImage in the latest release." >&2
  exit 1
fi

if [[ -f $VERSION_FILE && $(<"$VERSION_FILE") == "$tag" ]]; then
  echo "Bambu Studio $tag is already the latest version. Nothing to do."
  exit 0
fi

# The AppImage bundles most libraries but uses the system's WebKitGTK (for the
# home page, MakerWorld and the device tab), GStreamer (camera view) and GLU.
echo "Installing libraries Bambu Studio needs..."
sudo dnf install -y webkit2gtk4.1 libsoup3 mesa-libGLU \
  gstreamer1-plugins-base gstreamer1-plugins-good gstreamer1-plugins-bad-free

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "Downloading Bambu Studio $tag..."
curl -fL --progress-bar -o "$work/BambuStudio.AppImage" "$url"

if [[ -n $digest ]]; then
  echo "$digest  $work/BambuStudio.AppImage" | sha256sum --check --quiet
  echo "Checksum OK."
else
  echo "Warning: GitHub listed no checksum for this file; skipping the check." >&2
fi

echo "Unpacking..."
chmod +x "$work/BambuStudio.AppImage"
(cd "$work" && ./BambuStudio.AppImage --appimage-extract >/dev/null)

rm -rf "$INSTALL_DIR"
mkdir -p "$(dirname "$INSTALL_DIR")"
mv "$work/squashfs-root" "$INSTALL_DIR"
echo "$tag" >"$VERSION_FILE"

# Launcher. Bambu Studio's 3D view and web pages are unreliable on Wayland, so
# it runs through XWayland, and WebKit's DMA-BUF renderer is turned off because
# it leaves the home and device pages blank on some GPUs (NVIDIA especially).
# Set GDK_BACKEND or WEBKIT_DISABLE_DMABUF_RENDERER yourself to override.
mkdir -p "$(dirname "$BIN")"
cat >"$BIN" <<SH
#!/bin/bash
export GDK_BACKEND=\${GDK_BACKEND:-x11}
export WEBKIT_DISABLE_DMABUF_RENDERER=\${WEBKIT_DISABLE_DMABUF_RENDERER:-1}
exec "$INSTALL_DIR/AppRun" "\$@"
SH
chmod +x "$BIN"

# App menu entry: reuse the AppImage's own .desktop file (it lists the file
# types and the bambustudio:// link handler) but point it at the launcher.
src_desktop=$(find "$INSTALL_DIR" -maxdepth 1 -name '*.desktop' | head -1)
icon=$(find "$INSTALL_DIR" -maxdepth 1 -name '*.png' | head -1)
mkdir -p "$APPS_DIR" "$ICON_DIR"
[[ -n $icon ]] && cp "$icon" "$ICON_DIR/bambu-studio.png"

if [[ -n $src_desktop ]]; then
  sed -e "s|^Exec=[^ ]*|Exec=$BIN|" \
      -e "s|^Icon=.*|Icon=bambu-studio|" \
      -e "/^TryExec=/d" \
      -e "/^X-AppImage-/d" \
      "$src_desktop" >"$DESKTOP_FILE"
else
  cat >"$DESKTOP_FILE" <<DESKTOP
[Desktop Entry]
Name=Bambu Studio
GenericName=3D Printing Software
Exec=$BIN %U
Icon=bambu-studio
Terminal=false
Type=Application
Categories=Graphics;3DGraphics;Engineering;
MimeType=model/stl;model/3mf;application/vnd.ms-3mfdocument;application/prs.wavefront-obj;application/x-amf;x-scheme-handler/bambustudio;
StartupWMClass=bambu-studio
DESKTOP
fi

update-desktop-database "$APPS_DIR" 2>/dev/null || true
gtk-update-icon-cache -q "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor" 2>/dev/null || true

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "Note: ~/.local/bin isn't on your PATH, so 'bambu-studio' only works from the app menu." ;;
esac

echo ""
echo "Bambu Studio $tag installed. Run 'bambu-studio' or find Bambu Studio in the app menu."
echo "Run this script again to update."
