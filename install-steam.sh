#!/bin/bash
# Install Steam (native RPM from RPM Fusion, not Flatpak) on Fedora.
# Fedora port of omarchy's bin/omarchy-install-gaming-steam.

set -e

# Steam's 32-bit runtime only exists on x86_64.
if [[ $(uname -m) != x86_64 ]]; then
  echo "Steam needs an x86_64 system." >&2
  exit 1
fi

repo_enabled() {
  dnf repolist --enabled 2>/dev/null | awk '{print $1}' | grep -qx "$1"
}

# Fedora Workstation ships a ready-made, Steam-only RPM Fusion repo
# (fedora-workstation-repositories). Use that if possible, otherwise add the
# full RPM Fusion free + nonfree repos.
enable_steam_repo() {
  if repo_enabled rpmfusion-nonfree-steam || repo_enabled rpmfusion-nonfree; then
    echo "Steam repo already enabled."
  elif dnf repolist --all 2>/dev/null | awk '{print $1}' | grep -qx rpmfusion-nonfree-steam; then
    sudo dnf config-manager setopt rpmfusion-nonfree-steam.enabled=1
  else
    local fedora
    fedora=$(rpm -E %fedora)
    sudo dnf install -y \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$fedora.noarch.rpm" \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$fedora.noarch.rpm"
  fi
}

# Like omarchy's omarchy-install-gaming-gpu-lib32: pick 32-bit graphics drivers
# for the GPUs in this machine. The steam RPM already pulls in 32-bit Mesa
# (AMD/Intel), so only NVIDIA needs extra work, and only if the RPM Fusion
# NVIDIA driver is installed. This never installs the NVIDIA driver itself.
gpu_packages() {
  local packages=()
  if lspci | grep -iE '(VGA|3D|Display).*(AMD|ATI|Intel)' >/dev/null; then
    packages+=(mesa-vulkan-drivers.i686 mesa-dri-drivers.i686)
  fi
  if lspci | grep -iE '(VGA|3D|Display).*NVIDIA' >/dev/null; then
    if rpm -q xorg-x11-drv-nvidia >/dev/null 2>&1; then
      packages+=(xorg-x11-drv-nvidia-libs.i686)
    else
      echo "NVIDIA GPU found but the RPM Fusion NVIDIA driver isn't installed;" >&2
      echo "Steam will use the open-source driver (nouveau/NVK)." >&2
    fi
  fi
  echo "${packages[@]}"
}

if flatpak info com.valvesoftware.Steam >/dev/null 2>&1; then
  echo "Note: the Flatpak Steam is also installed. You may want to remove it:"
  echo "  flatpak uninstall com.valvesoftware.Steam"
fi

fresh=false
rpm -q steam >/dev/null 2>&1 || fresh=true

echo "Enabling Steam repository..."
enable_steam_repo

echo "Installing Steam and 32-bit graphics drivers..."
# shellcheck disable=SC2046
sudo dnf install -y steam $(gpu_packages)

echo ""
# Start it only after a fresh install (NO_LAUNCH=1 skips this; run-all.sh sets it).
if $fresh && [[ -z ${NO_LAUNCH:-} ]]; then
  echo "Steam will start now. The first launch downloads updates and can take a while..."
  setsid steam >/dev/null 2>&1 &
else
  echo "Steam is installed. The first launch downloads updates and can take a while."
fi
