#!/bin/bash
# Remove KDE apps that come with Fedora KDE but go unused: the KDE mail and
# calendar suite (KMail, Kontact, ...), the games and other extras, and Blender.
# LibreOffice is kept. Then clean up dependencies that nothing needs anymore.
#
# Safe to run again: packages that are already gone are skipped.
# To get one of the apps back, install it again with: sudo dnf install <package>

PACKAGES=(
  # KDE mail/calendar suite
  akregator kmail kontact korganizer kaddressbook akonadi-import-wizard
  grantlee-editor pim-data-exporter pim-sieve-editor
  # Games
  kmahjongg kmines kpat
  # Media and misc
  dragon elisa-player kamoso skanpage kmouth qrca neochat
  # Remote desktop
  krdc krfb
  # Big apps
  blender
)

installed=()
for pkg in "${PACKAGES[@]}"; do
  rpm -q "$pkg" >/dev/null 2>&1 && installed+=("$pkg")
done

if ((${#installed[@]})); then
  sudo dnf remove -y "${installed[@]}"
else
  echo "None of the extra KDE apps are installed, so there's nothing to remove."
fi

sudo dnf autoremove -y

echo ""
echo "Extra KDE apps have been removed."
