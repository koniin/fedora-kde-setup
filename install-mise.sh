#!/bin/bash
# Install mise, the tool Omarchy uses to manage programming language versions
# (Node, Bun, .NET, Python, ...). Omarchy activates it in bash with
# `eval "$(mise activate bash)"` (default/bash/init); this does the same in
# ~/.bashrc.d/mise.sh, which Fedora's .bashrc loads.
#
# mise isn't in Fedora's own repos, so the official installer (mise.run) is
# used. It checks the download and puts mise in ~/.local/bin, so no sudo is
# needed and `mise self-update` works.
#
# With mise active, the tool versions follow the folder you're in:
#   mise use -g node@lts   default for your user (~/.config/mise/config.toml)
#   mise use bun@1.3       pin for the current project (writes ./mise.toml)
#   mise install           install everything a project's mise.toml asks for
#   mise ls                show installed and active versions
#
# Install a language with install-dev-env.sh. Safe to run again.

set -euo pipefail

BASHRC_SNIPPET="$HOME/.bashrc.d/mise.sh"
MISE="$HOME/.local/bin/mise"

if command -v mise >/dev/null 2>&1; then
  echo "mise $(mise --version | awk '{print $1}') is already installed at $(command -v mise)."
else
  echo "Installing mise..."
  curl -fsSL https://mise.run | MISE_INSTALL_PATH="$MISE" sh
fi

echo "Writing $BASHRC_SNIPPET..."
mkdir -p "$(dirname "$BASHRC_SNIPPET")"
cat >"$BASHRC_SNIPPET" <<'BASH'
# Activate mise (from install-mise.sh), like Omarchy's default/bash/init.
if command -v mise &>/dev/null; then
  eval "$(mise activate bash)"
fi
BASH

echo ""
echo "mise is ready. Open a new terminal, or run: source ~/.bashrc"
echo "Then install a language, e.g.: ./install-dev-env.sh node"
