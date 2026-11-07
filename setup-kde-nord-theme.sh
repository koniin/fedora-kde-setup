#!/bin/bash
# Apply a Nord look to KDE Plasma 6 using EliverLara's Nordic theme
# (https://github.com/EliverLara/Nordic, GPLv3) plus Papirus-Dark icons.
#
# Nordic's "global theme" package is still in Plasma 5 format, so instead of
# lookandfeeltool this installs and applies each piece on its own:
#   colors, app style (Kvantum), window borders, cursors, icons, GTK, Konsole.
#
# Everything goes into your home directory (sudo is only used for dnf). Your
# old config files are backed up first. Safe to run again.
# Usually run through setup-kde-henke.sh, which also saves this look as the
# "Henke" global theme and sets up the login and lock screens.
#
# The wallpaper is set separately by setup-kde-wallpaper.sh.

set -e

REPO_URL="https://github.com/EliverLara/Nordic.git"
GTK_URL="https://github.com/EliverLara/Nordic/releases/latest/download/Nordic.tar.xz"

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP="$CONFIG/nord-theme-backup-$(date +%Y%m%d-%H%M%S)"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "Installing packages (Kvantum, Papirus icons)..."
sudo dnf install -y kvantum papirus-icon-theme git ImageMagick

echo "Backing up current config to $BACKUP..."
mkdir -p "$BACKUP"
for f in kdeglobals kwinrc konsolerc kscreenlockerrc gtk-3.0/settings.ini gtk-4.0/settings.ini Kvantum/kvantum.kvconfig; do
  [[ -f $CONFIG/$f ]] && install -D -m 644 "$CONFIG/$f" "$BACKUP/$f"
done

echo "Downloading Nordic..."
git clone --depth 1 --quiet "$REPO_URL" "$WORK/Nordic"
curl -fsSL "$GTK_URL" -o "$WORK/Nordic-gtk.tar.xz"
KDE="$WORK/Nordic/kde"

echo "Installing theme files..."
mkdir -p "$DATA/color-schemes" "$DATA/aurorae/themes" "$DATA/icons" \
         "$DATA/konsole" "$DATA/themes" "$CONFIG/Kvantum"
cp "$KDE"/colorschemes/*.colors "$DATA/color-schemes/"
cp -r "$KDE/aurorae/Nordic" "$DATA/aurorae/themes/"
cp -r "$KDE/cursors/Nordic-cursors" "$DATA/icons/"
cp "$KDE/konsole/Nordic.colorscheme" "$DATA/konsole/"
for theme in "$KDE"/kvantum/*/; do cp -r "$theme" "$CONFIG/Kvantum/"; done
rm -rf "$DATA/themes/Nordic"
tar -xJf "$WORK/Nordic-gtk.tar.xz" -C "$DATA/themes"

echo "Applying colors, icons and cursors..."
plasma-apply-colorscheme Nordic
/usr/libexec/plasma-changeicons Papirus-Dark
plasma-apply-cursortheme Nordic-cursors
# The Breeze Plasma style takes its colors from the color scheme, so the panel
# and menus turn Nord too.
plasma-apply-desktoptheme default

echo "Applying Kvantum app style..."
kwriteconfig6 --file "$CONFIG/Kvantum/kvantum.kvconfig" --group General --key theme Nordic
kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum

echo "Applying window borders..."
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme __aurorae__svg__Nordic
busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure

echo "Applying GTK theme..."
busctl --user call org.kde.GtkConfig /GtkConfig org.kde.GtkConfig setGtkTheme s Nordic

echo "Setting up Konsole profile..."
cat > "$DATA/konsole/Nord.profile" <<'PROFILE'
[Appearance]
ColorScheme=Nordic

[General]
Name=Nord
Parent=FALLBACK/
PROFILE
kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile Nord.profile

echo ""
echo "Nord theme applied. Already-open apps change when you restart them;"
echo "log out and back in to see it everywhere."
echo "Run ./setup-kde-henke.sh to save this look as the Henke global theme (so"
echo "switching global themes can't lose it) and set up the login and lock screens."
echo "To undo, copy files from $BACKUP back into ~/.config, or pick other themes in System Settings."
