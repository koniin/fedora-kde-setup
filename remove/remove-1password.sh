#!/bin/bash
# Remove 1Password, its browser extension policy, and its repo on Fedora.
# Fedora port of omarchy's bin/omarchy-remove-service-1password.

EXTENSION_ID="aeblfdkhhhdcdjpifhhbdiojplfjncoa"

sudo rm -f "/usr/share/chromium/extensions/$EXTENSION_ID.json" \
           "/opt/google/chrome/extensions/$EXTENSION_ID.json"
# Drop our Firefox policy entry, deleting the file if nothing else is left in it.
FIREFOX_ADDON_ID="{d634138d-c276-4fc8-924b-40a0ea21d284}"
FIREFOX_POLICY_FILE="/etc/firefox/policies/policies.json"
if [[ -f $FIREFOX_POLICY_FILE ]] && command -v jq >/dev/null 2>&1; then
  updated=$(sudo cat "$FIREFOX_POLICY_FILE" | jq --arg id "$FIREFOX_ADDON_ID" '
    del(.policies.ExtensionSettings[$id])
    | if .policies.ExtensionSettings == {} then del(.policies.ExtensionSettings) else . end
    | if .policies == {} then del(.policies) else . end')
  if [[ $updated == "{}" ]]; then
    sudo rm -f "$FIREFOX_POLICY_FILE"
  else
    sudo tee "$FIREFOX_POLICY_FILE" >/dev/null <<<"$updated"
  fi
fi

sudo dnf remove -y 1password 1password-cli
sudo rm -f /etc/yum.repos.d/1password.repo

echo ""
echo "1Password has been removed. The Firefox add-on stays in your profile; remove it from about:addons if you want it gone."
