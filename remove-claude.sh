#!/bin/bash
# Remove Claude Code installed by install-claude.sh (the native installer).
# Settings, login and history are kept unless you choose to delete them.

# -u so an unset HOME is an error rather than rm -rf paths rooted at /.
set -euo pipefail

rm -f "$HOME/.local/bin/claude"
rm -rf "$HOME/.local/share/claude" "$HOME/.cache/claude"

config=()
for p in "$HOME/.claude" "$HOME/.claude.json"; do [[ -e $p ]] && config+=("$p"); done
if ((${#config[@]} > 0)); then
  printf '  %s\n' "${config[@]}"
  read -rp "Delete Claude Code settings, login and conversation history too? [y/N] " answer
  [[ $answer == [yY]* ]] && rm -rf "${config[@]}" && echo "Settings deleted."
fi

echo ""
echo "Claude Code has been removed."
