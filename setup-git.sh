#!/bin/bash
# Sets your git name and email in ~/.gitconfig, used for every repository
# that doesn't set its own, and sets up GitHub login for git push/pull.
#
# GitHub doesn't accept passwords for git, so login goes through the GitHub
# CLI (gh): "gh auth login" logs you in through the browser and stores a token
# in your keyring, and "gh auth setup-git" makes git ask gh for that token
# when it talks to https://github.com. Undo with "gh auth logout".
#
# Installs git and gh from dnf if they're missing. Asks you to log in only if
# you aren't already. Safe to run again.

set -euo pipefail

GIT_NAME="Henrik Länsman"
GIT_EMAIL="henke@lnsmn.com"

MISSING=()
for pkg in git gh; do
  command -v "$pkg" >/dev/null || MISSING+=("$pkg")
done
if ((${#MISSING[@]})); then
  echo "Installing ${MISSING[*]}..."
  sudo dnf install -y "${MISSING[@]}"
else
  echo "git and gh are already installed."
fi

echo "Setting name to $GIT_NAME and email to $GIT_EMAIL..."
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

if gh auth status --hostname github.com >/dev/null 2>&1; then
  echo "Already logged in to GitHub."
else
  echo "Logging in to GitHub (opens your browser)..."
  gh auth login --hostname github.com --git-protocol https --web
fi

echo "Setting up git to use your GitHub login..."
gh auth setup-git --hostname github.com

echo ""
echo "Done. git push and pull to https://github.com now use your GitHub login."
