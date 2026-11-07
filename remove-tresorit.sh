#!/bin/bash
# Remove Tresorit installed by install-tresorit.sh. Your login and settings
# are kept unless you choose to delete them. Files you synced (your tresors'
# local folders) are never touched; they stay wherever you put them, and
# remain safe in your Tresorit account. ~/Cloud is left as it is.

set -euo pipefail

INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/tresorit"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

if pgrep -u "$USER" -x 'tresorit|tresorit-daemon' >/dev/null; then
  echo "Stopping Tresorit..."
  pkill -u "$USER" -x 'tresorit|tresorit-daemon' || true
  sleep 2
fi

rm -f "$APPS_DIR/tresorit.desktop" \
  "$HOME/.local/bin/tresorit" "$HOME/.local/bin/tresorit-cli" \
  "$HOME/.config/autostart/tresorit.desktop"
update-desktop-database "$APPS_DIR" 2>/dev/null || true

if [[ -d $INSTALL_DIR ]]; then
  # Program files (the same list Tresorit's own uninstaller deletes).
  (cd "$INSTALL_DIR" && rm -rf tresorit tresorit-daemon tresorit-cli \
    tresorit.config libTresorit.so tresorit.png uninstall.sh running.pid \
    LICENSES.txt UpdaterWatchdog QtQuick QtQuick.2 fonts Reports prefill)

  if [[ -n $(ls -A "$INSTALL_DIR") ]]; then
    read -rp "Delete your Tresorit login, settings and logs ($INSTALL_DIR) too? [y/N] " answer
    if [[ $answer == [yY]* ]]; then
      rm -rf "$INSTALL_DIR"
      echo "Settings deleted."
    fi
  else
    rmdir "$INSTALL_DIR"
  fi
fi

echo ""
echo "Tresorit has been removed."
