#!/bin/bash
# Remove Bambu Studio installed by install-bambu-studio.sh. Your printer
# profiles, presets and login are kept unless you choose to delete them.
# The libraries it installed (WebKitGTK, GStreamer) are left alone, since
# other apps use them too.

set -euo pipefail

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"

rm -rf "$HOME/.local/opt/bambu-studio"
rm -f "$HOME/.local/bin/bambu-studio" \
  "$DATA/applications/bambu-studio.desktop" \
  "$DATA/icons/hicolor/256x256/apps/bambu-studio.png"
update-desktop-database "$DATA/applications" 2>/dev/null || true

settings=()
for d in "$HOME/.config/BambuStudio" "$HOME/.cache/BambuStudio"; do
  [[ -e $d ]] && settings+=("$d")
done
if ((${#settings[@]} > 0)); then
  printf '  %s\n' "${settings[@]}"
  read -rp "Delete Bambu Studio settings, presets and cache too? [y/N] " answer
  [[ $answer == [yY]* ]] && rm -rf "${settings[@]}" && echo "Settings deleted."
fi

echo ""
echo "Bambu Studio has been removed."
