#!/bin/bash
# Install a development environment with mise, like Omarchy's
# bin/omarchy-install-dev-env. Installs mise first (install-mise.sh) if needed.
#
#   ./install-dev-env.sh node     Node.js LTS (with npm/npx)
#   ./install-dev-env.sh bun      Bun
#   ./install-dev-env.sh dotnet   .NET SDK
#
# Several at once work too: ./install-dev-env.sh node bun dotnet
#
# These become your user's defaults (mise use --global). A project can pin its
# own versions with `mise use <tool>@<version>` in its folder, which writes a
# mise.toml there; `mise install` in a project installs what it asks for.
#
# Omarchy installs `node` as latest; LTS is used here because tools like Vite
# and many npm packages target it. Remove with remove/remove-dev-env.sh.

set -euo pipefail

USAGE="Usage: $0 <node|bun|dotnet>..."
if (($# == 0)); then
  echo "$USAGE" >&2
  exit 1
fi

if ! command -v mise >/dev/null 2>&1; then
  "$(dirname "$(realpath "$0")")/install-mise.sh"
  export PATH="$HOME/.local/bin:$PATH"
fi

install_node() {
  echo -e "Installing Node.js...\n"
  mise use --global node@lts
}

install_bun() {
  echo -e "Installing Bun...\n"
  mise use --global bun@latest
}

install_dotnet() {
  echo -e "Installing .NET...\n"
  # .NET needs ICU, OpenSSL, Kerberos and zlib at runtime; Fedora's packages.
  MISSING=()
  for pkg in libicu openssl-libs krb5-libs zlib-ng-compat; do
    rpm -q "$pkg" >/dev/null 2>&1 || MISSING+=("$pkg")
  done
  if ((${#MISSING[@]})); then
    sudo dnf install -y "${MISSING[@]}"
  fi
  mise use --global dotnet@latest
}

for env in "$@"; do
  case "$env" in
  node) install_node ;;
  bun) install_bun ;;
  dotnet)
    install_dotnet
    echo -e "\nYou can now run: dotnet new webapi -o myproject"
    ;;
  *)
    echo "Unknown environment: $env" >&2
    echo "$USAGE" >&2
    exit 1
    ;;
  esac
done

echo ""
mise ls --global
echo ""
echo "Done. Open a new terminal (or run: source ~/.bashrc) if the commands aren't found."
