#!/bin/bash
# Add an omarchy-style "stay awake" coffee cup to the KDE Plasma panel.
# Click it to stop the screen from dimming, turning off, locking and the
# computer from sleeping; click again to go back to normal.
#
# Installs (for your user only, no sudo):
#   ~/.local/bin/kde-caffeine   toggle|on|off|status   (also usable from a shortcut)
#   a "Caffeine" panel widget, added to your panel automatically.
#
# Works like a video player keeping the screen on: it holds KDE's power
# management and screen saver inhibitions (kde-inhibit) while active.
# Stay-awake ends when you log out. Safe to run again.

set -euo pipefail

WIDGET_ID="local.caffeine"
HELPER="$HOME/.local/bin/kde-caffeine"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "Installing kde-caffeine helper..."
mkdir -p "$(dirname "$HELPER")"
cat >"$HELPER" <<'HELPER'
#!/bin/bash
# kde-caffeine: keep the screen awake. Usage: kde-caffeine [toggle|on|off|status]
# Prints the new state ("on" or "off").

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/kde-caffeine.pid"

is_on() {
  [[ -f $PIDFILE ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null
}

turn_on() {
  is_on && return
  # setsid gives the inhibitor its own process group so "off" can stop it
  # together with the sleep it runs.
  setsid kde-inhibit --power --screenSaver sleep infinity >/dev/null 2>&1 &
  echo $! >"$PIDFILE"
}

turn_off() {
  if is_on; then
    kill -- -"$(cat "$PIDFILE")" 2>/dev/null || kill "$(cat "$PIDFILE")" 2>/dev/null
  fi
  rm -f "$PIDFILE"
}

case "${1:-toggle}" in
  toggle) if is_on; then turn_off; else turn_on; fi ;;
  on) turn_on ;;
  off) turn_off ;;
  status) ;;
  *) echo "Usage: kde-caffeine [toggle|on|off|status]" >&2; exit 1 ;;
esac

if is_on; then echo on; else echo off; fi
HELPER
chmod +x "$HELPER"

echo "Building Caffeine panel widget..."
PKG="$WORK/$WIDGET_ID"
mkdir -p "$PKG/contents/ui"

cat >"$PKG/metadata.json" <<'JSON'
{
  "KPlugin": {
    "Id": "local.caffeine",
    "Name": "Caffeine",
    "Description": "Click to keep the screen awake",
    "Icon": "caffeine",
    "Category": "Power Management",
    "License": "MIT",
    "Version": "1.0"
  },
  "KPackageStructure": "Plasma/Applet",
  "X-Plasma-API-Minimum-Version": "6.0"
}
JSON

# The cup is drawn with vector paths in QML so it takes your theme's colors
# (accent color when on, text color when off). SVG files can't be recolored.
cat >"$PKG/contents/ui/Cup.qml" <<'QML'
import QtQuick
import QtQuick.Shapes

// Coffee cup drawn on a 24x24 grid, scaled to fit. "full" adds fill + steam.
Item {
    id: cup
    property color color: "white"
    property bool full: false
    readonly property real unit: Math.min(width, height) / 24

    Shape {
        width: 24; height: 24
        anchors.centerIn: parent
        scale: cup.unit
        preferredRendererType: Shape.CurveRenderer

        ShapePath {   // cup body
            strokeColor: cup.color; strokeWidth: 2
            fillColor: cup.full ? cup.color : "transparent"
            joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
            PathSvg { path: "M4 10h12v5a5 5 0 0 1-5 5H9a5 5 0 0 1-5-5z" }
        }
        ShapePath {   // handle
            strokeColor: cup.color; strokeWidth: 2; fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
            PathSvg { path: "M16 11.5h1.5a2.5 2.5 0 0 1 0 5H16" }
        }
        ShapePath {   // steam
            strokeColor: cup.full ? cup.color : "transparent"; strokeWidth: 2; fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M7 2.5c-1 1.2 1 2.3 0 3.5M10.5 2.5c-1 1.2 1 2.3 0 3.5M14 2.5c-1 1.2 1 2.3 0 3.5" }
        }
    }
}
QML

cat >"$PKG/contents/ui/main.qml" <<'QML'
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property bool active: false
    readonly property string helper: "\"$HOME/.local/bin/kde-caffeine\""

    Plasmoid.icon: "caffeine"
    // The button itself is the "full" view, so the panel always shows it
    // inline instead of collapsing it into a popup icon.
    preferredRepresentation: fullRepresentation
    toolTipMainText: active ? i18n("Staying awake") : i18n("Caffeine")
    toolTipSubText: active ? i18n("Click to let the screen sleep normally")
                           : i18n("Click to keep the screen awake")

    function run(args) {
        executable.connectSource(helper + " " + args)
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            const out = (data["stdout"] || "").trim()
            if (out === "on" || out === "off") {
                root.active = (out === "on")
            }
            disconnectSource(source)
        }
    }

    // Keep the icon right if it was toggled elsewhere (e.g. from a shortcut).
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.run("status")
    }

    fullRepresentation: MouseArea {
        hoverEnabled: true
        onClicked: root.run("toggle")

        Layout.minimumWidth: Kirigami.Units.iconSizes.small
        Layout.minimumHeight: Kirigami.Units.iconSizes.small
        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
        implicitWidth: Kirigami.Units.iconSizes.medium
        implicitHeight: Kirigami.Units.iconSizes.medium

        Cup {
            anchors.fill: parent
            full: root.active
            color: root.active ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
            opacity: parent.containsMouse ? 0.8 : 1
        }
    }
}
QML

echo "Installing widget..."
UPGRADED=false
if kpackagetool6 -t Plasma/Applet --show "$WIDGET_ID" >/dev/null 2>&1; then
  kpackagetool6 -t Plasma/Applet --upgrade "$PKG" >/dev/null
  UPGRADED=true
else
  kpackagetool6 -t Plasma/Applet --install "$PKG" >/dev/null
fi

echo "Adding Caffeine to your panel..."
busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s "
  const id = '$WIDGET_ID';
  const all = panels();
  const has = all.some(p => p.widgets().some(w => w.type === id));
  if (!has && all.length > 0) {
    all[0].addWidget(id);
  }
" >/dev/null

echo ""
echo "Done. Click the coffee cup in your panel to keep the screen awake."
echo "Right-click the panel -> Enter Edit Mode to move it, e.g. next to the clock."
if $UPGRADED; then
  echo "Updated an existing install: the panel keeps the old version until it restarts."
  echo "Restart it with: systemctl --user restart plasma-plasmashell"
fi
echo "For a keyboard shortcut: System Settings -> Keyboard -> Shortcuts -> Add New -> Command: kde-caffeine"
