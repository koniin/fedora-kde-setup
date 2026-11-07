#!/bin/bash
# Set up the whole "Henke" look in KDE Plasma in one go:
#   1. Installs the Nord theme pieces if they're missing (setup-kde-nord-theme.sh)
#   2. Creates the Henke global theme and applies it (setup-kde-henke-theme.sh)
#   3. Puts one wallpaper on every screen, the lock screen and the login
#      screen, and makes it the default for new screens (setup-kde-wallpaper.sh)
#   4. Gives the login screen your colors, fonts and cursors (setup-kde-nord-login.sh)
#
#   ./setup-kde-henke.sh                       # Nord wallpaper (wallpapers/0-black-moon.jpg)
#   ./setup-kde-henke.sh 1-city-view.webp      # another one from the wallpapers folder
#   ./setup-kde-henke.sh ~/Pictures/wall.jpg   # or your own image
#
# To switch wallpapers later, run ./setup-kde-wallpaper.sh and pick one.
#
# Every step checks first and skips itself if it's already done, so running
# this again only changes what's missing or out of date.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WALLPAPER="${1:-0-black-moon.jpg}"

# Check before changing anything (a name means a file in the wallpapers folder).
if [[ ! -f $WALLPAPER && ! -f $SCRIPT_DIR/wallpapers/$WALLPAPER ]]; then
  echo "Wallpaper not found: $WALLPAPER" >&2
  exit 1
fi

echo "== Global theme =="
"$SCRIPT_DIR/setup-kde-henke-theme.sh"

echo ""
echo "== Wallpaper =="
"$SCRIPT_DIR/setup-kde-wallpaper.sh" "$WALLPAPER"

if systemctl is-enabled --quiet plasmalogin.service 2>/dev/null; then
  echo ""
  echo "== Login screen look =="
  "$SCRIPT_DIR/setup-kde-nord-login.sh"
fi

echo ""
echo "All set."
