#!/bin/bash
# Set up 5 KDE Plasma virtual desktops with Hyprland/omarchy-style shortcuts:
#   Meta+1..5        switch to desktop N   (Ctrl+F1..F5 kept as alternates)
#   Meta+Shift+1..5  move window to desktop N
#
# Changes are applied live through KWin's D-Bus API, and KDE saves them to
# ~/.config/kwinrc and ~/.config/kglobalshortcutsrc. No logout needed.
# Safe to run again.

set -e

DESKTOPS=5

KWIN=(org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager)
ACCEL=(org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel)

# Qt key codes
META=$((0x10000000))
SHIFT=$((0x02000000))
CTRL=$((0x04000000))
KEY_0=$((0x30))
KEY_F1=$((0x01000030))

# For Shift+number, KWin drops Shift and matches the symbol the key produces,
# so "Meta+Shift+2" reaches KDE as Meta+" on Swedish and Meta+@ on US layouts.
# These are the Qt key codes for the shifted symbols of keys 1-5.
layout=$(kreadconfig6 --file kxkbrc --group Layout --key LayoutList | cut -d, -f1)
[[ -z $layout ]] && layout=$(localectl status | awk '/X11 Layout/ {print $3}' | cut -d, -f1)
case "$layout" in
  se | fi | no | dk) SHIFTED=(0x21 0x22 0x23 0xa4 0x25) ;; # ! " # ¤ %
  *)                 SHIFTED=(0x21 0x40 0x23 0x24 0x25) ;; # ! @ # $ % (US)
esac

# set_shortcut COMPONENT COMPONENT_NAME ACTION KEY...  (no KEY = unbind)
set_shortcut() {
  local component=$1 component_name=$2 action=$3
  shift 3
  busctl --user call "${ACCEL[@]}" setForeignShortcut asai \
    4 "$component" "$action" "$component_name" "$action" \
    $# "$@"
}

if ! busctl --user status org.kde.KWin >/dev/null 2>&1; then
  echo "KWin is not running. Run this from inside a KDE Plasma session." >&2
  exit 1
fi

echo "Setting up $DESKTOPS virtual desktops..."
count=$(busctl --user get-property "${KWIN[@]}" count | awk '{print $2}')
for ((i = count; i < DESKTOPS; i++)); do
  busctl --user call "${KWIN[@]}" createDesktop us "$i" "Desktop $((i + 1))"
done
busctl --user set-property "${KWIN[@]}" rows u 1
if ((count > DESKTOPS)); then
  echo "Note: you already have $count desktops; leaving the extra ones alone."
fi

echo "Freeing Meta+1..$DESKTOPS from the taskbar..."
for ((n = 1; n <= DESKTOPS; n++)); do
  set_shortcut plasmashell plasmashell "activate task manager entry $n"
done

echo "Binding desktop shortcuts (keyboard layout: ${layout:-unknown})..."
for ((n = 1; n <= DESKTOPS; n++)); do
  set_shortcut kwin KWin "Switch to Desktop $n" \
    $((META | (KEY_0 + n))) \
    $((CTRL | (KEY_F1 + n - 1)))

  set_shortcut kwin KWin "Window to Desktop $n" \
    $((META | ${SHIFTED[n - 1]})) \
    $((META | SHIFT | (KEY_0 + n)))
done

echo ""
echo "Done. $DESKTOPS desktops; Meta+N switches, Meta+Shift+N moves the active window."
