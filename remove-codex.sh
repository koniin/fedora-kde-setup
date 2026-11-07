#!/bin/bash
# Remove Codex installed by install-codex.sh (the standalone installer).
# Settings, login and history in ~/.codex are kept unless you choose to delete them.

# -u so an unset HOME is an error rather than rm -rf paths rooted at /.
set -euo pipefail

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

rm -f "$HOME/.local/bin/codex" "$HOME/.local/bin/codex-code-mode-host"
rm -rf "$CODEX_HOME/packages"

if [[ -d $CODEX_HOME ]]; then
  echo "  $CODEX_HOME"
  read -rp "Delete Codex settings, login and history too? [y/N] " answer
  [[ $answer == [yY]* ]] && rm -rf "$CODEX_HOME" && echo "Settings deleted."
fi

echo ""
echo "Codex has been removed."
