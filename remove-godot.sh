#!/bin/bash
# Remove Godot. Your projects are untouched; editor settings, export templates
# and cache are kept unless you choose to delete them.

set -e

sudo dnf remove -y godot

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
settings=()
for d in "$HOME/.config/godot" "$DATA/godot" "$HOME/.cache/godot"; do
  [[ -e $d ]] && settings+=("$d")
done
if ((${#settings[@]} > 0)); then
  printf '  %s\n' "${settings[@]}"
  read -rp "Delete Godot editor settings, export templates and cache too? [y/N] " answer
  [[ $answer == [yY]* ]] && rm -rf "${settings[@]}" && echo "Settings deleted."
fi

echo ""
echo "Godot has been removed."
