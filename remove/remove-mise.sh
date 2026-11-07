#!/bin/bash
# Remove mise installed by install-mise.sh, with every language version it
# installed (~/.local/share/mise) and its cache. Your settings in
# ~/.config/mise are kept unless you choose to delete them. Projects' mise.toml
# files are left alone.

# -u so an unset HOME is an error rather than rm -rf paths rooted at /.
set -euo pipefail

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/mise"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/mise"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/mise"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mise"

rm -f "$HOME/.bashrc.d/mise.sh" "$HOME/.local/bin/mise"
rm -rf "$DATA_DIR" "$CACHE_DIR" "$STATE_DIR"

if [[ -d $CONFIG_DIR ]]; then
  echo "  $CONFIG_DIR"
  read -rp "Delete mise settings and default tool versions too? [y/N] " answer
  [[ $answer == [yY]* ]] && rm -rf "$CONFIG_DIR" && echo "Settings deleted."
fi

echo ""
echo "mise has been removed. Open a new terminal to clear it from your shell."
