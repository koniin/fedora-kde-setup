#!/bin/bash
# Give the KDE login screen the same look as your desktop (colors, fonts,
# cursors). Usually run through setup-kde-henke.sh; run setup-kde-nord-theme.sh
# or setup-kde-henke-theme.sh first.
#
# Fedora KDE uses Plasma Login Manager, which can't load SDDM themes (Nordic's
# login themes are SDDM-only). It does read the greeter user's own Plasma
# config, so this copies your current settings there. That's the same set of
# files System Settings -> Login Screen -> "Apply Plasma Settings" copies.
# The cursor theme is installed system-wide so the greeter can see it.
#
# The login screen wallpaper is set by setup-kde-wallpaper.sh.
# Does nothing if the login screen already has your current settings; run it
# again after changing colors, fonts or cursors.

set -euo pipefail

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
CURSORS="$DATA/icons/Nordic-cursors"
FILES=(kdeglobals plasmarc kcminputrc)
# Remembers what was copied last time, so we can tell (without sudo) whether
# anything changed. The greeter's own files aren't readable by you.
STAMP="${XDG_STATE_HOME:-$HOME/.local/state}/system-install/login-look.sha256"

if ! systemctl is-enabled --quiet plasmalogin.service 2>/dev/null; then
  echo "Plasma Login Manager is not in use; nothing to do." >&2
  exit 1
fi

greeter_home=$(getent passwd plasmalogin | cut -d: -f6)
if [[ -z $greeter_home ]]; then
  echo "No plasmalogin user found; check your Plasma Login Manager install." >&2
  exit 1
fi

if [[ $(kreadconfig6 --file kdeglobals --group General --key ColorScheme) != Nordic* || ! -d $CURSORS ]]; then
  echo "Nord isn't applied to your desktop yet. Run ./setup-kde-henke.sh (or ./setup-kde-nord-theme.sh) first." >&2
  exit 1
fi

fingerprint() {
  (
    cd "$CONFIG"
    for f in "${FILES[@]}"; do [[ -f $f ]] && sha256sum "$f"; done
    cd "$CURSORS"
    find . -type f -exec sha256sum {} + | sort
  ) | sha256sum | cut -d' ' -f1
}

current=$(fingerprint)
if [[ -f $STAMP && $(<"$STAMP") == "$current" && -d /usr/share/icons/Nordic-cursors ]]; then
  echo "Login screen already has your current Plasma settings."
  exit 0
fi

echo "Installing Nordic cursors system-wide..."
sudo rm -rf /usr/share/icons/Nordic-cursors
sudo cp -r "$CURSORS" /usr/share/icons/
sudo chmod -R a+rX /usr/share/icons/Nordic-cursors

echo "Copying Plasma settings to the login screen..."
sudo install -d -o plasmalogin -g plasmalogin "$greeter_home/.config"
for f in "${FILES[@]}"; do
  [[ -f $CONFIG/$f ]] || continue
  sudo install -o plasmalogin -g plasmalogin -m 644 "$CONFIG/$f" "$greeter_home/.config/$f"
done

mkdir -p "$(dirname "$STAMP")"
echo "$current" >"$STAMP"

echo ""
echo "Login screen updated; you'll see it next time you log out."
