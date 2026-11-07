#!/bin/bash
# Install OpenAI Codex (the `codex` CLI). Omarchy installs it through mise with
# auto-updates; on Fedora the simplest match is OpenAI's official standalone
# installer, which puts it in ~/.local/bin (files in ~/.codex/packages).
# Does nothing if it's already installed.

set -euo pipefail

if command -v codex >/dev/null 2>&1; then
  echo "Codex $(codex --version 2>/dev/null | head -1) is already installed at $(command -v codex)."
  exit 0
fi

echo "Installing Codex..."
curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=true sh

echo ""
echo "Codex has been installed. Run 'codex' in a project folder to start."
