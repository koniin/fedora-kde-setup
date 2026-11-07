#!/bin/bash
# Omarchy-style keyboard shortcuts for KDE Plasma.
#
# In Omarchy (Hyprland) focus follows the mouse, so Meta+W closes the window
# under the pointer. FOCUS_FOLLOWS_MOUSE=true gives KDE the same behaviour:
# hovering a window focuses it. Set it to false for KDE's click-to-focus.
#
# Desktop switching shortcuts (Meta+1..5, Meta+Shift+1..5) live in
# setup-kde-desktops.sh.
#
# Meta+Return and Ctrl+Alt+T open foot if it's installed, otherwise Konsole.
# install-foot.sh runs this script again so the switch happens right away.
#
# Applied live through KDE's shortcut service and saved by KDE. Safe to run again.

set -euo pipefail

FOCUS_FOLLOWS_MOUSE=true

# Turn "Meta+Shift+Return" into the key code KDE expects.
keycode() {
  local code=0 part n
  IFS=+ read -ra parts <<<"$1"
  for part in "${parts[@]}"; do
    case "$part" in
      Meta) code=$((code | 0x10000000)) ;;
      Ctrl) code=$((code | 0x04000000)) ;;
      Alt) code=$((code | 0x08000000)) ;;
      Shift) code=$((code | 0x02000000)) ;;
      [A-Za-z0-9])
        printf -v n '%d' "'${part^^}"
        code=$((code | n))
        ;;
      Space) code=$((code | 0x20)) ;;
      Escape) code=$((code | 0x01000000)) ;;
      Tab) code=$((code | 0x01000001)) ;;
      Backspace) code=$((code | 0x01000003)) ;;
      Return) code=$((code | 0x01000004)) ;;
      Enter) code=$((code | 0x01000005)) ;;
      Delete) code=$((code | 0x01000007)) ;;
      Print) code=$((code | 0x01000009)) ;;
      Home) code=$((code | 0x01000010)) ;;
      End) code=$((code | 0x01000011)) ;;
      Left) code=$((code | 0x01000012)) ;;
      Up) code=$((code | 0x01000013)) ;;
      Right) code=$((code | 0x01000014)) ;;
      Down) code=$((code | 0x01000015)) ;;
      Search) code=$((code | 0x01000092)) ;;
      F[0-9] | F[0-9][0-9]) code=$((code | (0x01000030 + ${part#F} - 1))) ;;
      *) echo "Unknown key '$part' in '$1'" >&2; exit 1 ;;
    esac
  done
  echo "$code"
}

# bind COMPONENT COMPONENT_NAME ACTION ACTION_NAME [KEY...]   (no KEY = unbind)
# Replaces all keys of the action with the ones given.
bind() {
  local component=$1 component_name=$2 action=$3 action_name=$4
  shift 4
  local codes=() key
  for key in "$@"; do codes+=("$(keycode "$key")"); done
  local id=(4 "$component" "$action" "$component_name" "$action_name")
  # Registers the action first, so this also works on a fresh install.
  busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel doRegister as "${id[@]}"
  busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel setForeignShortcut asai \
    "${id[@]}" ${#codes[@]} "${codes[@]}"
  # App launchers that are new to KDE stay inactive until the next login.
  # Marking them present (SetPresent | NoAutoloading) makes the keys work now.
  if [[ $component == *.desktop ]]; then
    busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel setShortcut asaiu \
      "${id[@]}" ${#codes[@]} "${codes[@]}" 6 >/dev/null
  fi
  echo "  ${action_name}: ${*:-none}"
}

if ! busctl --user status org.kde.kglobalaccel >/dev/null 2>&1; then
  echo "KDE's shortcut service isn't running. Run this from inside a Plasma session." >&2
  exit 1
fi

echo "Setting shortcuts..."

# Windows
bind kwin KWin "Overview" "Toggle Overview" Meta+Shift+W  # moved off Meta+W
bind kwin KWin "Window Close" "Close Window" Meta+W Alt+F4

# Apps
# The terminal is foot if it's installed (install-foot.sh), otherwise Konsole.
# The desktop file was renamed in foot 1.20; use whichever this package ships.
FOOT_DESKTOP=""
for id in foot.desktop org.codeberg.dnkl.foot.desktop; do
  [[ -f /usr/share/applications/$id ]] && FOOT_DESKTOP=$id
done
if [[ -n $FOOT_DESKTOP ]] && command -v foot >/dev/null; then
  bind org.kde.konsole.desktop Konsole _launch Konsole
  bind "$FOOT_DESKTOP" Foot _launch Foot Ctrl+Alt+T Meta+Return
else
  bind org.kde.konsole.desktop Konsole _launch Konsole Ctrl+Alt+T Meta+Return
fi
bind org.mozilla.firefox.desktop Firefox _launch Firefox Meta+Shift+Return
bind org.kde.krunner.desktop KRunner _launch KRunner Alt+Space Meta+Space Search Alt+F2

# Activities
bind plasmashell plasmashell "next activity" "Walk through activities" Meta+A
bind plasmashell plasmashell "previous activity" "Walk through activities (Reverse)" Meta+Shift+A

if $FOCUS_FOLLOWS_MOUSE; then
  echo "Turning on focus follows mouse..."
  kwriteconfig6 --file kwinrc --group Windows --key FocusPolicy FocusFollowsMouse
else
  kwriteconfig6 --file kwinrc --group Windows --key FocusPolicy ClickToFocus
fi
busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure

echo ""
echo "Done."
