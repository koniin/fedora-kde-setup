#!/bin/bash
# Remove Steam on Fedora. Fedora port of omarchy's bin/omarchy-remove-gaming-steam.
# Omarchy always deletes your Steam data; this asks first, because it includes
# every installed game and any saves that aren't in Steam Cloud.

set -e

if rpm -q steam >/dev/null 2>&1; then
  sudo dnf remove -y steam
else
  echo "steam is not installed."
fi

DATA_DIRS=(
  "$HOME/.steam"
  "$HOME/.local/share/Steam"
  "$HOME/.config/steam"
  "$HOME/.cache/steam"
)

existing=()
for d in "${DATA_DIRS[@]}"; do [[ -e $d ]] && existing+=("$d"); done

if ((${#existing[@]} > 0)); then
  echo ""
  echo "Steam data (games, settings, local saves):"
  du -sh "${existing[@]}" 2>/dev/null || printf '  %s\n' "${existing[@]}"
  read -rp "Delete it too? [y/N] " answer
  if [[ $answer == [yY]* ]]; then
    rm -rf "${existing[@]}"
    echo "Steam data deleted."
  else
    echo "Kept Steam data."
  fi
fi

echo ""
echo "Steam has been removed."
