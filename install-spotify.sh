#!/bin/bash
# Install Spotify on Fedora.
# Fedora port of omarchy's bin/omarchy-install-service-spotify.
#
# On x86_64 this installs the native Spotify client (spotify-client RPM from
# negativo17's Spotify repo, a repackaging of Spotify's own Linux build), so
# it's /usr/bin/spotify just like on omarchy. Spotify only builds its Linux
# client for x86_64, so elsewhere (like omarchy) it adds the web player
# (open.spotify.com) as an app instead.

set -e

REPO_URL="https://negativo17.org/repos/fedora-spotify.repo"
REPO_FILE="/etc/yum.repos.d/fedora-spotify.repo"
WEB_URL="https://open.spotify.com/"
ICON_URL="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/spotify.png"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

install_native() {
  if [[ -f $REPO_FILE ]]; then
    echo "Spotify repo already configured."
  else
    echo "Adding the negativo17 Spotify repository..."
    sudo dnf config-manager addrepo --from-repofile="$REPO_URL"
  fi

  echo "Installing Spotify..."
  sudo dnf install -y spotify-client

  if flatpak info com.spotify.Client >/dev/null 2>&1; then
    echo "Note: the Flatpak Spotify is also installed. You may want to remove it:"
    echo "  flatpak uninstall com.spotify.Client"
  fi

  echo "Opening Spotify..."
  setsid /usr/bin/spotify >/dev/null 2>&1 &
}

# Like omarchy's omarchy-webapp-install: an app menu entry that opens the
# web player. Here it opens in your default browser.
install_webapp() {
  echo "Spotify has no Linux client for $(uname -m); installing Spotify as a web app..."
  mkdir -p "$APPS_DIR/icons"
  curl -fsSL -o "$APPS_DIR/icons/Spotify.png" "$ICON_URL" || true

  cat >"$APPS_DIR/Spotify.desktop" <<DESKTOP
[Desktop Entry]
Version=1.0
Name=Spotify
Comment=Spotify web player
Exec=xdg-open $WEB_URL
Terminal=false
Type=Application
Icon=$APPS_DIR/icons/Spotify.png
Categories=Audio;Music;Player;AudioVideo;
StartupNotify=true
DESKTOP
  chmod +x "$APPS_DIR/Spotify.desktop"
  update-desktop-database "$APPS_DIR" 2>/dev/null || true

  echo "Opening Spotify..."
  setsid xdg-open "$WEB_URL" >/dev/null 2>&1 &
}

if [[ $(uname -m) == x86_64 ]]; then
  install_native
else
  install_webapp
fi

echo ""
echo "Spotify has been installed."
