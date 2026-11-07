#!/bin/bash
# Remove a development environment installed by install-dev-env.sh: drops it
# from your mise defaults and deletes its installed versions. Versions a
# project's mise.toml pins are deleted too; `mise install` there brings them back.
#
#   ./remove-dev-env.sh node|bun|dotnet...

set -euo pipefail

USAGE="Usage: $0 <node|bun|dotnet>..."
if (($# == 0)); then
  echo "$USAGE" >&2
  exit 1
fi

if ! command -v mise >/dev/null 2>&1; then
  echo "mise isn't installed, so there's nothing to remove."
  exit 0
fi

remove_tool() {
  echo "Removing $1..."
  mise unuse --global --yes "$1" 2>/dev/null || true
  mise uninstall --all "$1" 2>/dev/null || true
}

for env in "$@"; do
  case "$env" in
  node | bun | dotnet) remove_tool "$env" ;;
  *)
    echo "Unknown environment: $env" >&2
    echo "$USAGE" >&2
    exit 1
    ;;
  esac
done

echo ""
echo "Done. Still installed:"
mise ls
