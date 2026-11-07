#!/bin/bash
# Remove the Caffeine panel widget and kde-caffeine helper.

set -euo pipefail

WIDGET_ID="local.caffeine"
HELPER="$HOME/.local/bin/kde-caffeine"

# Let the screen sleep again before removing the helper.
[[ -x $HELPER ]] && "$HELPER" off >/dev/null

busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s "
  panels().forEach(p => p.widgets().forEach(w => { if (w.type === '$WIDGET_ID') w.remove(); }));
" >/dev/null || true

kpackagetool6 -t Plasma/Applet --remove "$WIDGET_ID" >/dev/null 2>&1 || true
rm -f "$HELPER"

echo "Caffeine has been removed."
