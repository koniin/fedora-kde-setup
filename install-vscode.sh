#!/bin/bash
# Install Visual Studio Code on Fedora and apply sensible defaults.
# Fedora port of omarchy's bin/omarchy-install-vscode:
#   - installs from Microsoft's official RPM repo (instead of the AUR package)
#   - sets the keyring backend in ~/.vscode/argv.json
#   - turns off VS Code's built-in updater (dnf handles updates)
#   - installs and selects the Nord theme to match the KDE Nord setup

set -euo pipefail

KEY_URL="https://packages.microsoft.com/keys/microsoft.asc"
REPO_FILE="/etc/yum.repos.d/vscode.repo"
SETTINGS_FILE="$HOME/.config/Code/User/settings.json"
ARGV_FILE="$HOME/.vscode/argv.json"
THEME_EXTENSION="arcticicestudio.nord-visual-studio-code"
THEME_NAME="Nord"

add_repo() {
  if [[ -f $REPO_FILE ]]; then
    echo "VS Code repo already configured."
    return
  fi

  sudo rpm --import "$KEY_URL"
  sudo tee "$REPO_FILE" >/dev/null <<REPO
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=$KEY_URL
REPO
}

# Pick the keyring VS Code stores secrets in. Omarchy forces gnome-libsecret
# because Hyprland isn't a desktop VS Code can detect; on KDE use KWallet.
write_argv() {
  local store="gnome-libsecret"
  [[ ${XDG_CURRENT_DESKTOP:-} == *KDE* ]] && store="kwallet6"

  mkdir -p "$(dirname "$ARGV_FILE")"
  cat >"$ARGV_FILE" <<EOF
// This configuration file allows you to pass permanent command line arguments to VS Code.
// Only a subset of arguments is currently supported to reduce the likelihood of breaking
// the installation.
//
// PLEASE DO NOT CHANGE WITHOUT UNDERSTANDING THE IMPACT
//
// NOTE: Changing this file requires a restart of VS Code.
{
  "password-store": "$store"
}
EOF
  echo "Set VS Code password store to $store."
}

# Set a string key in settings.json. settings.json may contain comments, so
# edit it with sed rather than jq. Existing settings are kept.
set_setting() {
  local key="$1" value="$2"
  if grep -q "\"$key\"" "$SETTINGS_FILE"; then
    sed -i --follow-symlinks -E \
      "s/(\"$key\"[[:space:]]*:[[:space:]]*\")[^\"]*(\")/\1$value\2/" "$SETTINGS_FILE"
  else
    sed -i --follow-symlinks -E "0,/\{/{s/\{/{\n  \"$key\": \"$value\",/}" "$SETTINGS_FILE"
  fi
}

write_settings() {
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  [[ -f $SETTINGS_FILE ]] || printf '{\n}\n' >"$SETTINGS_FILE"

  # Updates come from dnf, so turn off VS Code's own updater.
  set_setting "update.mode" "none"

  if ! code --list-extensions 2>/dev/null | grep -Fxqi "$THEME_EXTENSION"; then
    echo "Installing $THEME_NAME theme..."
    code --install-extension "$THEME_EXTENSION" 2>&1 |
      grep -v -e DeprecationWarning -e trace-deprecation || true
    if ! code --list-extensions 2>/dev/null | grep -Fxqi "$THEME_EXTENSION"; then
      echo "Warning: couldn't install the $THEME_NAME theme." >&2
    fi
  fi
  set_setting "workbench.colorTheme" "$THEME_NAME"

  # Clean up a trailing comma left by inserting into an empty object.
  sed -i --follow-symlinks -Ez 's/,(\s*)\}\s*$/\1}\n/' "$SETTINGS_FILE"
}

echo "Adding VS Code repository..."
add_repo

# openssl3-libs: VS Code checks extension signatures with vsce-sign, a .NET
# program that only knows OpenSSL 3 and older. Fedora ships OpenSSL 4, so
# without the OpenSSL 3 compat libraries vsce-sign crashes ("No usable version
# of libssl was found") and every extension install fails with "Signature
# verification failed with 'UnknownError'".
echo "Installing VS Code..."
sudo dnf install -y code openssl3-libs

echo "Configuring VS Code..."
write_argv
write_settings

echo "Opening VS Code..."
setsid code >/dev/null 2>&1 &

echo ""
echo "VS Code has been installed. Update it with 'sudo dnf upgrade code'."
