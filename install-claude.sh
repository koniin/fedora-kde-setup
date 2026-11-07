#!/bin/bash
# Install Claude Code (the `claude` CLI). Omarchy installs it through mise with
# auto-updates; on Fedora the simplest match is Anthropic's official native
# installer, which puts it in ~/.local/bin and keeps it updated by itself.
# Does nothing if it's already installed.

set -euo pipefail

if command -v claude >/dev/null 2>&1; then
  echo "Claude Code $(claude --version 2>/dev/null | head -1) is already installed at $(command -v claude)."
  echo "It updates itself; run 'claude update' to update now."
  exit 0
fi

echo "Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash

echo ""
echo "Claude Code has been installed. Run 'claude' in a project folder to start."
