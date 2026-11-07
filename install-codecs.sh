#!/bin/bash
# Install full multimedia codecs on Fedora: RPM Fusion's ffmpeg (H.264, HEVC,
# AAC, ...) instead of Fedora's patent-stripped ffmpeg-free, plus the
# "freeworld" Mesa VA-API driver so AMD GPUs can hardware-decode H.264/HEVC.
# Fixes e.g. Twitch "Error #4000" in Firefox.

set -e

repo_enabled() {
  dnf repolist --enabled 2>/dev/null | awk '{print $1}' | grep -qx "$1"
}

# Fedora Workstation only ships single-purpose RPM Fusion repos (steam, nvidia);
# ffmpeg needs the full RPM Fusion free repo.
enable_rpmfusion_free() {
  if repo_enabled rpmfusion-free; then
    echo "RPM Fusion free already enabled."
  else
    sudo dnf install -y \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
  fi
}

install_ffmpeg() {
  if rpm -q ffmpeg >/dev/null 2>&1; then
    echo "RPM Fusion ffmpeg already installed."
  elif rpm -q ffmpeg-free >/dev/null 2>&1; then
    # --allowerasing lets dnf replace the *-free libraries (libavcodec-free etc.).
    sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
  else
    sudo dnf install -y ffmpeg --allowerasing
  fi
}

# Fedora's Mesa disables H.264/HEVC/VC-1 in VA-API. RPM Fusion's freeworld
# build re-enables them. Older Fedora ships the VA driver as mesa-va-drivers;
# newer releases fold it into mesa-dri-drivers. Never --allowerasing here:
# removing mesa-dri-drivers would take the desktop down with it.
install_mesa_freeworld() {
  if ! lspci | grep -iE '(VGA|3D|Display).*(AMD|ATI)' >/dev/null; then
    echo "No AMD GPU found; skipping Mesa freeworld VA-API driver."
    return
  fi
  if rpm -q mesa-va-drivers-freeworld >/dev/null 2>&1; then
    echo "Mesa freeworld VA-API driver already installed."
  elif rpm -q mesa-va-drivers >/dev/null 2>&1; then
    sudo dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
  elif sudo dnf install -y mesa-va-drivers-freeworld; then
    :
  else
    echo "Couldn't install mesa-va-drivers-freeworld (it may conflict with" >&2
    echo "mesa-dri-drivers on this Fedora release, or lag behind a Mesa update)." >&2
    echo "Video will still play, but H.264/HEVC decode on the CPU." >&2
  fi
}

echo "Enabling RPM Fusion free..."
enable_rpmfusion_free

echo "Installing full ffmpeg..."
install_ffmpeg

echo "Installing hardware video decoding driver..."
install_mesa_freeworld

echo ""
if command -v vainfo >/dev/null 2>&1; then
  echo "VA-API profiles (look for H264 and HEVC):"
  vainfo 2>/dev/null | grep -E 'VAProfile(H264|HEVC)' || echo "  none found"
else
  echo "Install libva-utils and run 'vainfo' to check hardware decoding."
fi
echo ""
echo "Done. Fully quit and restart Firefox for the new codecs to take effect."
