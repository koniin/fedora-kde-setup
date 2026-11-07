#!/bin/bash
# Use Omarchy's system font, JetBrainsMono Nerd Font, everywhere in KDE Plasma.
#
# Like omarchy-font-set, this makes it the fontconfig "monospace" font (used by
# terminals and anything asking for monospace). Omarchy's desktop shell uses it
# for all its text too, so on KDE it's also set as the general, menu, toolbar,
# small and window title font. GTK apps follow automatically.
#
# The font comes from the official Nerd Fonts release (Fedora only packages
# plain JetBrains Mono without the Nerd Font icons). It's installed system-wide
# in /usr/local/share/fonts, so the login screen can use it too.
# Safe to run again; it skips the download if the font is already installed.

set -euo pipefail

FONT="JetBrainsMono Nerd Font"
RELEASE="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
FONT_DIR="/usr/local/share/fonts/JetBrainsMonoNerdFont"
FONTCONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/conf.d/50-omarchy-monospace.conf"

# Point sizes, matching KDE's defaults.
SIZE=10
SMALL_SIZE=8
TOOLBAR_SIZE=9

if fc-list : family | grep -qxF "$FONT"; then
  echo "$FONT is already installed."
else
  echo "Downloading $FONT..."
  WORK=$(mktemp -d)
  trap 'rm -rf "$WORK"' EXIT
  curl -fL --progress-bar "$RELEASE/JetBrainsMono.tar.xz" -o "$WORK/JetBrainsMono.tar.xz"
  curl -fsSL "$RELEASE/SHA-256.txt" -o "$WORK/SHA-256.txt"

  echo "Verifying checksum..."
  (cd "$WORK" && grep ' JetBrainsMono\.tar\.xz$' SHA-256.txt | sha256sum -c --quiet -)

  echo "Installing to $FONT_DIR..."
  mkdir -p "$WORK/fonts"
  # Only the regular "Nerd Font" family (the archive also has Mono/Propo variants).
  tar -xJf "$WORK/JetBrainsMono.tar.xz" -C "$WORK/fonts" --wildcards 'JetBrainsMonoNerdFont-*.ttf'
  sudo mkdir -p "$FONT_DIR"
  sudo install -m 644 "$WORK"/fonts/*.ttf "$FONT_DIR/"
  sudo fc-cache -f "$FONT_DIR" >/dev/null
fi

echo "Making it the monospace font (like omarchy-font-set)..."
mkdir -p "$(dirname "$FONTCONFIG_FILE")"
cat >"$FONTCONFIG_FILE" <<XML
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="pattern">
    <test name="family" qual="any">
      <string>monospace</string>
    </test>
    <edit name="family" mode="prepend_first" binding="strong">
      <string>$FONT</string>
    </edit>
  </match>
</fontconfig>
XML
fc-cache -f >/dev/null

echo "Setting KDE fonts..."
# Qt font strings: family,pointSize,pixelSize,styleHint,weight,italic,underline,strikeout,fixedPitch,raw
font() { echo "$FONT,$1,-1,5,50,0,0,0,0,0"; }
kwriteconfig6 --notify --file kdeglobals --group General --key font "$(font $SIZE)"
kwriteconfig6 --notify --file kdeglobals --group General --key fixed "$(font $SIZE)"
kwriteconfig6 --notify --file kdeglobals --group General --key menuFont "$(font $SIZE)"
kwriteconfig6 --notify --file kdeglobals --group General --key toolBarFont "$(font $TOOLBAR_SIZE)"
kwriteconfig6 --notify --file kdeglobals --group General --key smallestReadableFont "$(font $SMALL_SIZE)"
kwriteconfig6 --notify --file kdeglobals --group WM --key activeFont "$(font $SIZE)"

echo ""
echo "Done. Monospace is now: $(fc-match monospace -f '%{family}' | cut -d, -f1)"
echo "Running apps pick up the new font when restarted; log out and back in to see it everywhere."
echo "Run ./setup-kde-nord-login.sh again to use the font on the login screen too."
