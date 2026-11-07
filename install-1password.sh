#!/bin/bash
# Install 1Password (desktop + CLI) and its Chromium/Chrome extension on Fedora.
# Fedora port of omarchy's bin/omarchy-install-service-1password.

set -e

EXTENSION_ID="aeblfdkhhhdcdjpifhhbdiojplfjncoa"
WEBSTORE_UPDATE_URL="https://clients2.google.com/service/update2/crx"
KEY_URL="https://downloads.1password.com/linux/keys/1password.asc"
REPO_FILE="/etc/yum.repos.d/1password.repo"
FIREFOX_ADDON_ID="{d634138d-c276-4fc8-924b-40a0ea21d284}"
FIREFOX_ADDON_URL="https://addons.mozilla.org/firefox/downloads/latest/1password-x-password-manager/latest.xpi"
FIREFOX_POLICY_FILE="/etc/firefox/policies/policies.json"

# External-extension directories for Chromium-based browsers installed as RPMs.
declare -A EXTENSION_DIRS=(
  [chromium-browser]="/usr/share/chromium/extensions"
  [google-chrome-stable]="/opt/google/chrome/extensions"
)

add_repo() {
  if [[ -f $REPO_FILE ]]; then
    echo "1Password repo already configured."
    return
  fi

  sudo rpm --import "$KEY_URL"
  sudo tee "$REPO_FILE" >/dev/null <<REPO
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$KEY_URL
REPO
}

install_browser_extensions() {
  local found=false
  for browser in "${!EXTENSION_DIRS[@]}"; do
    command -v "$browser" >/dev/null 2>&1 || continue
    found=true
    local dir="${EXTENSION_DIRS[$browser]}"
    sudo mkdir -p "$dir"
    printf '{ "external_update_url": "%s" }\n' "$WEBSTORE_UPDATE_URL" | sudo tee "$dir/$EXTENSION_ID.json" >/dev/null
    sudo chmod 644 "$dir/$EXTENSION_ID.json"
    echo "Added 1Password extension for $browser."
  done
  $found || echo "No RPM Chromium/Chrome found; skipping Chromium extension."
}

# Firefox has no external-extension folder like Chromium, but it reads an
# enterprise policy file. "normal_installed" auto-installs the add-on from
# addons.mozilla.org on next start; it stays enabled-by-default but can be
# disabled by the user. Existing policies in the file are preserved.
install_firefox_extension() {
  if ! command -v firefox >/dev/null 2>&1; then
    echo "Firefox is not installed; skipping Firefox add-on."
    return
  fi

  local current='{}'
  [[ -f $FIREFOX_POLICY_FILE ]] && current=$(sudo cat "$FIREFOX_POLICY_FILE")

  local updated
  updated=$(jq --arg id "$FIREFOX_ADDON_ID" --arg url "$FIREFOX_ADDON_URL" \
    '.policies.ExtensionSettings[$id] = { installation_mode: "normal_installed", install_url: $url }' \
    <<<"$current")

  sudo mkdir -p "$(dirname "$FIREFOX_POLICY_FILE")"
  sudo tee "$FIREFOX_POLICY_FILE" >/dev/null <<<"$updated"
  sudo chmod 644 "$FIREFOX_POLICY_FILE"
  echo "Added 1Password add-on policy for Firefox."
}

echo "Adding 1Password repository..."
add_repo

echo "Installing 1Password..."
sudo dnf install -y 1password 1password-cli jq

echo "Installing 1Password browser extension..."
install_browser_extensions
install_firefox_extension

echo "Opening 1Password..."
setsid 1password >/dev/null 2>&1 &

echo ""
echo "1Password has been installed. Restart your browser to load the extension."
