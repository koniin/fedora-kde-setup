#!/bin/bash
# Install Tresorit (end-to-end encrypted cloud storage) from Tresorit's
# official Linux installer, for your user only (no sudo).
#
# Installs into ~/.local/share/tresorit (where Tresorit's own installer puts
# it), with an app menu entry that also handles tresorit:// links, and
# `tresorit` / `tresorit-cli` commands in ~/.local/bin.
#
# Also creates ~/Cloud, the folder for things you want always synced. After
# logging in, sync a tresor (e.g. one called "Cloud") to it; see the steps
# printed at the end. Tresorit can't pick a tresor's local folder from the
# command line, so that one step is done in the app.
#
# Tresorit updates itself, so if it's already installed this only makes sure
# ~/Cloud exists. Pass --reinstall to reinstall it anyway (your login and
# settings are kept).

set -euo pipefail

INSTALLER_URL="https://installer.tresorit.com/tresorit_installer.run"
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/tresorit"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
BIN_DIR="$HOME/.local/bin"
CLOUD_DIR="$HOME/Cloud"

print_cloud_steps() {
  echo ""
  echo "To sync ~/Cloud, in the Tresorit app:"
  echo "  1. Log in, then create a tresor called \"Cloud\" (or pick an existing one)."
  echo "  2. Open the tresor's menu, choose Sync, and set the folder to $CLOUD_DIR."
  echo "Everything you put in ~/Cloud is then synced."
}

if [[ $(uname -m) != x86_64 ]]; then
  echo "This script only supports x86_64." >&2
  exit 1
fi

mkdir -p "$CLOUD_DIR"

if [[ -x $INSTALL_DIR/tresorit && ${1:-} != --reinstall ]]; then
  echo "Tresorit is already installed in $INSTALL_DIR and keeps itself up to date."
  echo "Run '$0 --reinstall' to reinstall it."
  print_cloud_steps
  exit 0
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "Downloading the Tresorit installer..."
curl -fL --progress-bar -o "$work/tresorit_installer.run" "$INSTALLER_URL"

if ! head -c 2 "$work/tresorit_installer.run" | grep -q '^#!'; then
  echo "The download doesn't look like Tresorit's installer." >&2
  exit 1
fi

# If Tresorit is running, stop it so its files can be replaced.
if pgrep -u "$USER" -x 'tresorit|tresorit-daemon' >/dev/null; then
  echo "Stopping the running Tresorit..."
  pkill -u "$USER" -x 'tresorit|tresorit-daemon' || true
  sleep 2
fi

# The installer's own "--update-v2 DIR" mode installs into DIR without asking
# questions; otherwise it's identical to a normal install. It checks the
# download's integrity, unpacks it and adds the app menu entry.
echo "Installing Tresorit into $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
sh "$work/tresorit_installer.run" --update-v2 "$INSTALL_DIR"
echo
# A normal install also records the installer's name; Tresorit reads it on
# first start.
echo "tresorit_installer.run" >"$INSTALL_DIR/prefill"

update-desktop-database "$APPS_DIR" 2>/dev/null || true

mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/tresorit" "$BIN_DIR/tresorit"
ln -sf "$INSTALL_DIR/tresorit-cli" "$BIN_DIR/tresorit-cli"

version=$(sed -n 's/^Version=//p' "$APPS_DIR/tresorit.desktop" 2>/dev/null || true)

echo "Opening Tresorit..."
setsid "$INSTALL_DIR/tresorit" >/dev/null 2>&1 &

echo ""
echo "Tresorit ${version:+$version }has been installed. Find it in the app menu or run 'tresorit'."
print_cloud_steps
