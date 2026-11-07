#!/bin/bash
# Install Godot from Fedora's repos, or upgrade it if Fedora has a newer
# version. Does nothing if the newest Fedora version is already installed.

set -e

if flatpak info org.godotengine.Godot >/dev/null 2>&1; then
  echo "Note: the Flatpak Godot is also installed: flatpak uninstall org.godotengine.Godot"
fi

latest=$(dnf -q repoquery --latest-limit 1 --qf '%{version}-%{release}\n' godot | tail -1)
if [[ -z $latest ]]; then
  echo "No godot package found in your enabled repos." >&2
  exit 1
fi

if installed=$(rpm -q --qf '%{version}-%{release}' godot 2>/dev/null); then
  if [[ $installed == "$latest" ]]; then
    echo "Godot $installed is already the latest version in Fedora. Nothing to do."
    exit 0
  fi
  echo "Upgrading Godot $installed -> $latest..."
  sudo dnf upgrade -y godot
else
  echo "Installing Godot $latest..."
  sudo dnf install -y godot
fi

echo ""
echo "Godot $(rpm -q --qf '%{version}' godot) installed. Run 'godot' or find Godot Engine in the app menu."
