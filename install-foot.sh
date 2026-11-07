#!/bin/bash
# Install the foot terminal with Omarchy's config and its Nord theme colors.
#
# Copies Omarchy's foot.ini (config/foot/foot.ini): JetBrainsMono Nerd Font
# size 11 (Omarchy uses 9), 14px padding, a 1050x750 window (foot defaults
# to 700x500), 10k lines of scrollback, a block cursor that doesn't
# blink, Ctrl+Shift+C/V copy and paste, no middle-click paste, and
# Shift+Return sent as CSI-u so TUIs can tell it apart from Return.
#
# The colors come from Omarchy's themes/nord/colors.toml, filled into its foot
# template (default/themed/foot.ini.tpl). They go in ~/.config/foot/themes/nord.ini,
# which foot.ini includes, so you can switch themes by changing one line.
#
# Like Omarchy, foot also becomes the default terminal (KDE's TerminalApplication,
# used by "Open Terminal Here" in Dolphin and by .desktop apps with Terminal=true),
# and setup-kde-shortcuts.sh is run again so Meta+Return opens foot.
#
# A foot.ini that differs from this one is backed up to foot.ini.bak first.
# Safe to run again.

set -euo pipefail

FONT="JetBrainsMono Nerd Font"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/foot"
THEME_FILE="$CONFIG_DIR/themes/nord.ini"

if command -v foot >/dev/null; then
  echo "foot is already installed."
else
  echo "Installing foot..."
  sudo dnf install -y foot
fi

echo "Writing Nord theme to $THEME_FILE..."
mkdir -p "$(dirname "$THEME_FILE")"
cat >"$THEME_FILE" <<'INI'
# Omarchy's Nord theme for foot.
[colors-dark]
foreground=d8dee9
background=2e3440
# Only matters if you make the background see-through with alpha=.
blur=yes
selection-foreground=d8dee9
selection-background=434c5e

cursor=2e3440 d8dee9

regular0=2e3440
regular1=bf616a
regular2=a3be8c
regular3=ebcb8b
regular4=81a1c1
regular5=b48ead
regular6=88c0d0
regular7=d8dee9

bright0=4c566a
bright1=bf616a
bright2=a3be8c
bright3=ebcb8b
bright4=81a1c1
bright5=b48ead
bright6=8fbcbb
bright7=d8dee9
INI

NEW_INI=$(mktemp)
trap 'rm -f "$NEW_INI"' EXIT
cat >"$NEW_INI" <<'INI'
[main]
include=~/.config/foot/themes/nord.ini
term=xterm-256color
font=JetBrainsMono Nerd Font:size=11
pad=14x14
initial-window-mode=windowed
initial-window-size-pixels=1050x750
workers=0

[scrollback]
lines=10000
multiplier=7.0

[cursor]
style=block
blink=no

[key-bindings]
clipboard-copy=Control+Insert Control+Shift+c XF86Copy
primary-paste=none
clipboard-paste=Shift+Insert Control+Shift+v XF86Paste

[text-bindings]
# Send Shift+Return as CSI-u so TUIs can distinguish it from Return.
\x1b[13;2u=Shift+Return
# Send Alt+Shift+Return as CSI-u so tmux can match M-S-Enter.
\x1b[13;4u=Mod1+Shift+Return
INI

# Back up only a config that isn't already ours, so running this again doesn't
# overwrite the backup of your original with a copy of this script's config.
if [[ -f $CONFIG_DIR/foot.ini ]] && ! cmp -s "$NEW_INI" "$CONFIG_DIR/foot.ini"; then
  cp "$CONFIG_DIR/foot.ini" "$CONFIG_DIR/foot.ini.bak"
  echo "Backed up your old config to $CONFIG_DIR/foot.ini.bak"
fi
echo "Writing $CONFIG_DIR/foot.ini..."
install -m 644 "$NEW_INI" "$CONFIG_DIR/foot.ini"

echo "Making foot the default terminal..."
# The desktop file was renamed in foot 1.20; use whichever this package ships.
DESKTOP_ID=foot.desktop
[[ -f /usr/share/applications/org.codeberg.dnkl.foot.desktop ]] && DESKTOP_ID=org.codeberg.dnkl.foot.desktop
kwriteconfig6 --notify --file kdeglobals --group General --key TerminalApplication foot
kwriteconfig6 --notify --file kdeglobals --group General --key TerminalService "$DESKTOP_ID"

echo "Checking the config..."
foot --check-config

# Moves Meta+Return and Ctrl+Alt+T from Konsole to foot.
SHORTCUTS="$(dirname "$0")/setup-kde-shortcuts.sh"
if [[ -x $SHORTCUTS ]]; then
  echo "Updating shortcuts..."
  "$SHORTCUTS"
fi

echo ""
echo "Done. Open foot from the app launcher or run: foot"
if ! fc-list : family | grep -qxF "$FONT"; then
  echo "Note: $FONT isn't installed, so foot falls back to another font."
  echo "Run ./setup-kde-font.sh to install it."
fi
