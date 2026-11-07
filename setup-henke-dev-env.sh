#!/bin/bash
# Set up Henke's development environment in one go: mise with Node.js LTS,
# Bun and the .NET SDK as your defaults (install-dev-env.sh, which installs
# mise first if it's missing).
#
#   ./setup-henke-dev-env.sh
#
# Running this again is safe: it only installs versions you don't have yet
# (e.g. a newer Bun or .NET release).
# Remove with remove/remove-dev-env.sh node bun dotnet.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

"$SCRIPT_DIR/install-dev-env.sh" node bun dotnet
