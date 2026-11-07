#!/bin/bash
# Remove Spotify installed by install-spotify.sh (the native client and its
# repo, or the web app entry). Your Spotify login and cache are kept.

set -e

APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

if rpm -q spotify-client >/dev/null 2>&1; then
  sudo dnf remove -y spotify-client
fi
sudo rm -f /etc/yum.repos.d/fedora-spotify.repo

rm -f "$APPS_DIR/Spotify.desktop" "$APPS_DIR/icons/Spotify.png"
update-desktop-database "$APPS_DIR" 2>/dev/null || true

echo ""
echo "Spotify has been removed. Its settings and cache are still in ~/.config/spotify and ~/.cache/spotify."
