#!/bin/bash
# Create a global theme called "Henke" (the Nord look) and make it the current
# global theme. Usually run through setup-kde-henke.sh, which also sets the
# wallpaper and the login screen.
#
# Why a global theme: switching global themes in System Settings overwrites the
# colors, icons, cursors, widget style and window borders. With Henke as a
# global theme, switching back to it restores the whole Nord look. Its default
# wallpaper (set by setup-kde-wallpaper.sh) is also what Plasma uses on screens
# you connect later.
#
# The theme only lists which pieces to use; the pieces themselves (Nordic
# colors, window borders, cursors, Kvantum style) come from
# setup-kde-nord-theme.sh, which this runs first if they're missing.
# The theme is created in ~/.local/share/plasma/look-and-feel/henke if it
# doesn't exist yet; to rebuild it, delete that folder and run this again.
# Does nothing if Henke is already set up and applied.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
THEME_ID="henke"
THEME_NAME="Henke"
THEME_DIR="$DATA/plasma/look-and-feel/$THEME_ID"
# Same marker setup-kde-wallpaper.sh looks for to refresh the theme previews.
MARKER=".made-by-system-install"

# What the theme sets: "file|group|key|value". Breeze's Plasma style takes its
# colors from the color scheme, so the panel and menus turn Nord too.
SETTINGS=(
  "kdeglobals|KDE|widgetStyle|kvantum"
  "kdeglobals|General|ColorScheme|Nordic"
  "kdeglobals|Icons|Theme|Papirus-Dark"
  "plasmarc|Theme|name|default"
  "kcminputrc|Mouse|cursorTheme|Nordic-cursors"
  "kwinrc|org.kde.kdecoration2|library|org.kde.kwin.aurorae"
  "kwinrc|org.kde.kdecoration2|theme|__aurorae__svg__Nordic"
  "ksplashrc|KSplash|Theme|org.kde.breeze.desktop"
)
# Settings a global theme can't hold, set directly instead.
KVANTUM_THEME="Nordic"
GTK_THEME="Nordic"

nord_installed() {
  [[ -f $DATA/color-schemes/Nordic.colors &&
     -d $DATA/aurorae/themes/Nordic &&
     ( -d $DATA/icons/Nordic-cursors || -d /usr/share/icons/Nordic-cursors ) &&
     -d $CONFIG/Kvantum/$KVANTUM_THEME &&
     -d $DATA/themes/$GTK_THEME &&
     -d /usr/share/icons/Papirus-Dark ]]
}

# Is Henke the current global theme, with all its settings still in place?
henke_applied() {
  [[ -f $THEME_DIR/contents/defaults ]] || return 1
  [[ $(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage) == "$THEME_ID" ]] || return 1
  [[ $(kreadconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel) != true ]] || return 1
  local entry file group key value
  for entry in "${SETTINGS[@]}"; do
    IFS='|' read -r file group key value <<<"$entry"
    # Plasma may drop a key that holds its default value, so treat a missing
    # plasmarc style (default: "default") as set.
    local fallback=""
    [[ $file == plasmarc ]] && fallback="$value"
    [[ $(kreadconfig6 --file "$file" --group "$group" --key "$key" --default "$fallback") == "$value" ]] || return 1
  done
  [[ $(kreadconfig6 --file "$CONFIG/Kvantum/kvantum.kvconfig" --group General --key theme) == "$KVANTUM_THEME" ]] || return 1
  [[ $(kreadconfig6 --file "$CONFIG/gtk-3.0/settings.ini" --group Settings --key gtk-theme-name) == "$GTK_THEME" ]] || return 1
}

if henke_applied; then
  echo "Global theme $THEME_NAME is already set up and applied."
  exit 0
fi

if ! nord_installed; then
  echo "Nord theme pieces are missing; running setup-kde-nord-theme.sh first..."
  "$SCRIPT_DIR/setup-kde-nord-theme.sh"
  echo ""
fi

if [[ -d $THEME_DIR ]]; then
  echo "Global theme $THEME_NAME already exists in $THEME_DIR."
else
  echo "Creating global theme $THEME_NAME in $THEME_DIR..."
  mkdir -p "$THEME_DIR/contents"
  cat >"$THEME_DIR/metadata.json" <<JSON
{
    "KPackageStructure": "Plasma/LookAndFeel",
    "KPlugin": {
        "Authors": [
            {
                "Name": "$THEME_NAME"
            }
        ],
        "Description": "Nord colors, Nordic window borders and cursors, Papirus icons",
        "Id": "$THEME_ID",
        "License": "GPLv2+",
        "Name": "$THEME_NAME"
    }
}
JSON
  # The settings Plasma applies when this global theme is chosen, written as
  # [file][group] key=value. Anything not in the package (lock screen, splash
  # screen and so on) comes from Breeze. setup-kde-wallpaper.sh adds the
  # [Wallpaper] default.
  defaults="$THEME_DIR/contents/defaults"
  : >"$defaults"
  for entry in "${SETTINGS[@]}"; do
    IFS='|' read -r file group key value <<<"$entry"
    kwriteconfig6 --file "$defaults" --group "$file" --group "$group" --key "$key" "$value"
  done
  touch "$THEME_DIR/$MARKER"
fi

echo "Applying global theme $THEME_NAME..."
# This also turns off automatic light/dark theme switching, which would
# otherwise swap Henke out for Breeze.
plasma-apply-lookandfeel --apply "$THEME_ID"

echo "Applying Kvantum and GTK themes..."
kwriteconfig6 --file "$CONFIG/Kvantum/kvantum.kvconfig" --group General --key theme "$KVANTUM_THEME"
busctl --user call org.kde.GtkConfig /GtkConfig org.kde.GtkConfig setGtkTheme s "$GTK_THEME"
busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure

echo ""
echo "$THEME_NAME is now your global theme. Already-open apps change when you"
echo "restart them; log out and back in to see it everywhere."
echo "Pick it again any time in System Settings -> Colors & Themes -> Global Theme."
