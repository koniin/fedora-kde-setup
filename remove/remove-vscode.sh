#!/bin/bash
# Remove Visual Studio Code and its repo on Fedora.
# Settings and extensions in ~/.config/Code and ~/.vscode are kept.

if rpm -q code >/dev/null 2>&1; then
  sudo dnf remove -y code
else
  echo "code is not installed."
fi
sudo rm -f /etc/yum.repos.d/vscode.repo

echo ""
echo "VS Code has been removed. Your settings and extensions are still in"
echo "~/.config/Code and ~/.vscode; delete those folders if you want them gone."
