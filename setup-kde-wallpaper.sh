#!/bin/bash
# Pick a wallpaper from the wallpapers folder next to this script and use it
# everywhere in KDE Plasma: the desktop on every connected screen, the default
# for screens you connect later, the lock screen (Meta+L) and the login screen.
#
#   ./setup-kde-wallpaper.sh                    # choose from a list
#   ./setup-kde-wallpaper.sh 0-black-moon.jpg   # a file in the wallpapers folder
#   ./setup-kde-wallpaper.sh ~/Pictures/x.jpg   # or any image file
#
# To add a choice, copy an image into the wallpapers folder. The Nord ones there
# come from Omarchy's Nord theme (https://github.com/omacom/omarchy, MIT).
#
# The chosen image is copied to /usr/local/share/wallpapers, because the login
# screen runs as the plasmalogin user and can't read files in your home folder.
# Everything points at that one copy, so it all matches.
#
# About new screens: Plasma saves a wallpaper for each screen separately. A
# screen it hasn't seen before gets no saved wallpaper, so it shows your global
# theme's default (Breeze Dark's is "Next"). This script changes that default
# when your global theme is your own (see setup-kde-henke-theme.sh); system
# themes are left alone.
# Safe to run again.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WALLPAPERS="$SCRIPT_DIR/wallpapers"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
WALLPAPER_DIR="/usr/local/share/wallpapers"
PREFIX="shared-wallpaper"
# The login screen wallpaper has to go in the main config file. Drop-ins in
# /etc/plasmalogin.conf.d rank below Fedora's /usr/lib/plasmalogin/defaults.conf
# for these keys, so Fedora's default wallpaper would win. System Settings ->
# Login Screen writes to this same file.
LOGIN_CONF="/etc/plasmalogin.conf"
# Older login wallpaper setups (setup-kde-nord-login.sh and earlier versions of
# this script). They don't work and are removed.
OLD_LOGIN_FILES=(
  /etc/plasmalogin.conf.d/nord-wallpaper.conf
  /etc/plasmalogin.conf.d/wallpaper.conf
  /usr/share/wallpapers/nord-login.png
)
# Marks a global theme made by setup-kde-henke-theme.sh.
MARKER=".made-by-system-install"

# The images in the wallpapers folder, sorted by name.
choices=()
if [[ -d $WALLPAPERS ]]; then
  while IFS= read -r -d '' f; do
    [[ $(file -b --mime-type "$f") == image/* ]] && choices+=("$f")
  done < <(find "$WALLPAPERS" -maxdepth 1 -type f -print0 | sort -z)
fi

list_choices() {
  local f
  for f in "${choices[@]}"; do echo "  ${f##*/}" >&2; done
}

# The installed copy is named after a hash of the image, so the one whose hash
# matches is the wallpaper in use now.
current_hash=""
for old in "$WALLPAPER_DIR/$PREFIX"-*; do
  [[ -d $old ]] && current_hash="${old##*-}"
done

pick() {
  if [[ ${#choices[@]} -eq 0 ]]; then
    echo "No images in $WALLPAPERS. Copy some there, or pass an image:" >&2
    echo "  $0 ~/Pictures/my-wallpaper.jpg" >&2
    exit 1
  fi
  if [[ ! -t 0 ]]; then
    echo "Pass the wallpaper to use, one of:" >&2
    list_choices
    exit 1
  fi
  echo "Wallpapers in $WALLPAPERS:" >&2
  local i f mark
  for i in "${!choices[@]}"; do
    f="${choices[$i]}"
    mark=""
    [[ -n $current_hash && $(sha256sum "$f" | cut -c1-12) == "$current_hash" ]] && mark="  (current)"
    printf '  %d) %s %s%s\n' $((i + 1)) "${f##*/}" \
      "$(magick identify -format '%wx%h' "$f[0]" 2>/dev/null)" "$mark" >&2
  done
  local n
  while true; do
    read -rp "Pick a wallpaper [1-${#choices[@]}]: " n
    if [[ $n =~ ^[0-9]+$ ]] && ((n >= 1 && n <= ${#choices[@]})); then
      image="${choices[$((n - 1))]}"
      return
    fi
  done
}

image="${1:-}"
if [[ -z $image ]]; then
  pick
elif [[ ! -e $image && -f $WALLPAPERS/$image ]]; then
  image="$WALLPAPERS/$image"
fi

if [[ ! -f $image ]]; then
  echo "Wallpaper not found: $image" >&2
  if [[ ${#choices[@]} -gt 0 ]]; then
    echo "In $WALLPAPERS:" >&2
    list_choices
  fi
  exit 1
fi
if [[ $(file -b --mime-type "$image") != image/* ]]; then
  echo "Not an image file: $image" >&2
  exit 1
fi
echo "Using $image"

# Install it as a Plasma wallpaper package (a folder with
# contents/images/<width>x<height>.<ext>), since a global theme's default
# wallpaper has to be one. The folder is named after the image's contents, so
# Plasma never shows a cached old image and running again with the same
# picture changes nothing.
ext="${image##*.}"
ext="${ext,,}"
hash=$(sha256sum "$image" | cut -c1-12)
size=$(magick identify -format '%wx%h' "$image[0]")
package="$WALLPAPER_DIR/$PREFIX-$hash"
target="$package/contents/images/$size.$ext"

lnf=$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)
lnf_dir="$DATA/plasma/look-and-feel/$lnf"
# Only global themes in your home folder (like the one
# setup-kde-henke-theme.sh makes) get their default changed.
own_theme=false
[[ -n $lnf && -f $lnf_dir/contents/defaults ]] && own_theme=true
use_login=false
systemctl is-enabled --quiet plasmalogin.service 2>/dev/null && use_login=true

# Read a login screen wallpaper key from $LOGIN_CONF.
login_key() {
  kreadconfig6 --file "$LOGIN_CONF" --group Greeter --group Wallpaper \
    --group org.kde.image --group General --key "$1"
}

# Does every desktop (one per screen and activity) show the wallpaper?
# Desktops have an activityId; panels and the system tray don't.
all_desktops_set() {
  awk -v want="file://$target" '
    /^\[Containments\]\[[0-9]+\]$/ { id = $0; sect = "main"; next }
    /^\[Containments\]\[[0-9]+\]\[Wallpaper\]\[org\.kde\.image\]\[General\]$/ {
      match($0, /^\[Containments\]\[[0-9]+\]/); id = substr($0, 1, RLENGTH); sect = "image"; next
    }
    /^\[/ { sect = ""; next }
    sect == "main" && /^activityId=./ { desktop[id] = 1 }
    sect == "image" && /^Image=/ { image[id] = substr($0, 7) }
    END {
      found = 0
      for (d in desktop) { found = 1; if (image[d] != want) exit 1 }
      exit !found
    }' "$CONFIG/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null
}

already_done() {
  [[ -f $target ]] || return 1
  all_desktops_set || return 1
  [[ $(kreadconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper \
       --group org.kde.image --group General --key Image) == "file://$target" ]] || return 1
  if $own_theme; then
    [[ $(kreadconfig6 --file "$lnf_dir/contents/defaults" --group Wallpaper --key Image) == "$package" ]] || return 1
  fi
  if $use_login; then
    [[ $(kreadconfig6 --file "$LOGIN_CONF" --group Greeter --key WallpaperPluginId) == org.kde.image ]] || return 1
    [[ $(login_key Image) == "file://$target" ]] || return 1
    local f
    for f in "${OLD_LOGIN_FILES[@]}"; do [[ ! -e $f ]] || return 1; done
  fi
  local old
  for old in "$WALLPAPER_DIR/$PREFIX"-*; do
    [[ -e $old && $old != "$package" ]] && return 1
  done
  return 0
}

if already_done; then
  echo "Wallpaper is already set everywhere ($target)."
  exit 0
fi

if [[ -f $target ]]; then
  echo "Wallpaper is already installed in $package."
else
  echo "Installing wallpaper to $package..."
  sudo install -d -m 755 "$package/contents/images"
  sudo install -m 644 "$image" "$target"
  sudo tee "$package/metadata.json" >/dev/null <<JSON
{
    "KPlugin": {
        "Id": "$PREFIX-$hash",
        "Name": "Shared wallpaper"
    }
}
JSON
  sudo chmod 644 "$package/metadata.json"
fi

echo "Setting desktop wallpaper on all screens..."
plasma-apply-wallpaperimage "$target"

echo "Setting lock screen wallpaper..."
kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin org.kde.image
for key in Image PreviewImage; do
  kwriteconfig6 --file kscreenlockerrc \
    --group Greeter --group Wallpaper --group org.kde.image --group General \
    --key "$key" "file://$target"
done

echo "Setting default wallpaper for new screens..."
# A screen Plasma hasn't seen before has no saved wallpaper and shows the
# global theme's default, so set that too. System themes such as Breeze Dark
# are left alone.
if $own_theme; then
  kwriteconfig6 --file "$lnf_dir/contents/defaults" --group Wallpaper --key Image "$package"
  # Refresh the previews shown in System Settings for themes our scripts made.
  if [[ -f $lnf_dir/$MARKER ]]; then
    mkdir -p "$lnf_dir/contents/previews"
    magick "$image[0]" -resize 1280x720^ -gravity center -extent 1280x720 \
      "$lnf_dir/contents/previews/fullscreenpreview.jpg"
    magick "$image[0]" -resize 600x338^ -gravity center -extent 600x338 \
      "$lnf_dir/contents/previews/preview.png"
  fi
  default_note=""
else
  default_note="Your global theme (${lnf:-Breeze}) is a system theme, so screens you connect later
will show its default wallpaper. Run ./setup-kde-henke.sh to use your own theme."
fi

if $use_login; then
  echo "Setting login screen wallpaper..."
  # Replace only the [Greeter] sections, keeping the rest of plasmalogin.conf
  # (including its commented-out defaults) as it is.
  new_conf=$(
    awk '/^\[/ { skip = ($0 ~ /^\[Greeter\]/) } !skip' "$LOGIN_CONF" |
      sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
    cat <<CONF

[Greeter]
WallpaperPluginId=org.kde.image

[Greeter][Wallpaper][org.kde.image][General]
Image=file://$target
PreviewImage=file://$target
CONF
  )
  printf '%s\n' "$new_conf" | sudo tee "$LOGIN_CONF.new" >/dev/null
  sudo chmod 644 "$LOGIN_CONF.new"
  sudo mv "$LOGIN_CONF.new" "$LOGIN_CONF"
  for old in "${OLD_LOGIN_FILES[@]}"; do
    if [[ -e $old ]]; then
      echo "Removing $old (replaced by $LOGIN_CONF)..."
      sudo rm -f "$old"
    fi
  done
else
  echo "Plasma Login Manager is not in use; skipping the login screen." >&2
fi

# Remove earlier wallpapers set by this script.
for old in "$WALLPAPER_DIR/$PREFIX"-*; do
  [[ -e $old && $old != "$package" ]] && sudo rm -rf "$old"
done

echo ""
echo "Done. The desktop changed right away; the lock screen uses it next time"
echo "you lock (Meta+L), and the login screen next time you log out."
if [[ -n $default_note ]]; then
  echo ""
  echo "$default_note"
else
  echo "New screens use it after you've logged out and back in once."
fi
