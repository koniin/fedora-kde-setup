#!/bin/bash
# Undo install-codecs.sh: go back to Fedora's own ffmpeg-free and Mesa VA-API
# driver. Asks before disabling RPM Fusion free, since other packages
# (e.g. Steam's dependencies) may come from it.

set -e

available() {
  [[ -n $(dnf repoquery --available --qf '%{name}\n' "$1" 2>/dev/null) ]]
}

if rpm -q mesa-va-drivers-freeworld >/dev/null 2>&1; then
  echo "Restoring Fedora's Mesa VA-API driver..."
  if available mesa-va-drivers; then
    sudo dnf swap -y mesa-va-drivers-freeworld mesa-va-drivers
  else
    # Newer Fedora ships the VA driver inside mesa-dri-drivers. Reinstall it
    # so any files the freeworld package replaced are restored.
    sudo dnf remove -y mesa-va-drivers-freeworld
    sudo dnf reinstall -y mesa-dri-drivers
  fi
else
  echo "Mesa freeworld VA-API driver not installed."
fi

if rpm -q ffmpeg >/dev/null 2>&1; then
  echo "Switching back to Fedora's ffmpeg-free..."
  # --allowerasing lets dnf replace RPM Fusion's ffmpeg-libs with the *-free libraries.
  sudo dnf swap -y ffmpeg ffmpeg-free --allowerasing
else
  echo "RPM Fusion ffmpeg not installed."
fi

if rpm -q rpmfusion-free-release >/dev/null 2>&1; then
  echo ""
  read -rp "Also remove the RPM Fusion free repository? [y/N] " answer
  if [[ $answer == [yY]* ]]; then
    if rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
      echo "Kept it: RPM Fusion nonfree is installed and depends on it." >&2
    else
      sudo dnf remove -y rpmfusion-free-release
      echo "RPM Fusion free removed."
    fi
  else
    echo "Kept RPM Fusion free."
  fi
fi

echo ""
echo "Codecs reverted to Fedora defaults. H.264 video (e.g. Twitch) will stop"
echo "working in Firefox unless the real openh264 is installed:"
echo "  sudo dnf swap noopenh264 openh264 && sudo dnf install mozilla-openh264"
echo "Fully quit and restart Firefox for the change to take effect."
