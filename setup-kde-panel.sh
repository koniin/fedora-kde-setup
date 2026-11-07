#!/bin/bash
# Set up the KDE Plasma panel: size and position, with the clock in the middle.
#
# Layout (left to right):
#   app launcher, pager, task manager, <spacer> caffeine clock <spacer>, system tray, show desktop
# The two expanding spacers make Plasma center the caffeine cup + clock on the bar. Any other
# widgets you've added stay on the left, in their current order. Widget settings
# (pinned apps, tray items) are kept; the clock gets the settings below.
#
# Restarts the panel at the end if the widget order changed, so the new order
# takes effect. Safe to run again.

set -euo pipefail

# Panel size and position (captured from the current setup).
LOCATION="top"        # top | bottom | left | right
HEIGHT=22             # thickness in pixels
ALIGNMENT="center"    # left | center | right
LENGTH_MODE="fill"    # fill | fit | custom
HIDING="none"         # none | autohide | dodgewindows | windowsgobelow
FLOATING=true         # floating panel with a gap from the screen edge
OPACITY="adaptive"    # adaptive | opaque | translucent

# Clock settings (captured from the current setup).
CLOCK_DATE_DISPLAY="BesideTime"   # BesideTime | BelowTime | Adaptive
# Date as 2026-11-05. The trailing \u2003 is an "em space": it makes the gap
# between the date and the time wider (a normal space would be trimmed).
CLOCK_DATE_FORMAT='yyyy-MM-dd\u2003'
# The clock uses the system font (see setup-kde-font.sh) at the size that fits the panel.

plasma_script() {
  busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s "$1" |
    sed -e 's/^s "//' -e 's/"$//' -e 's/\\n/\n/g' -e 's/\\"/"/g'
}

# Finds the panel to manage: on the primary screen at $LOCATION, else the first
# panel, else a new one.
FIND_PANEL="
  let p = panels().find(p => p.screen === 0 && p.location === '$LOCATION') || panels()[0];
  if (!p) { p = new Panel('org.kde.panel'); p.addWidget('org.kde.plasma.kickoff'); p.addWidget('org.kde.plasma.icontasks'); p.addWidget('org.kde.plasma.systemtray'); }
"

echo "Setting panel size and position..."
plasma_script "
  $FIND_PANEL
  p.location = '$LOCATION';
  p.height = $HEIGHT;
  p.alignment = '$ALIGNMENT';
  p.lengthMode = '$LENGTH_MODE';
  p.hiding = '$HIDING';
  p.floating = $FLOATING;
  p.opacity = '$OPACITY';
" >/dev/null

echo "Adding the clock and two expanding spacers..."
plasma_script "
  $FIND_PANEL
  p.widgets('org.kde.plasma.marginsseparator').forEach(w => w.remove());
  if (p.widgets('org.kde.plasma.digitalclock').length === 0) p.addWidget('org.kde.plasma.digitalclock');
  let spacers = p.widgets('org.kde.plasma.panelspacer');
  for (let i = spacers.length; i < 2; i++) p.addWidget('org.kde.plasma.panelspacer');
  p.widgets('org.kde.plasma.panelspacer').slice(2).forEach(w => w.remove());
  p.widgets('org.kde.plasma.panelspacer').forEach(w => {
    w.currentConfigGroup = ['General'];
    w.writeConfig('expanding', true);
  });
" >/dev/null

# Give the panel a moment to save its own layout before we write the order.
sleep 2

echo "Arranging widgets..."
arranged=$(plasma_script "
  $FIND_PANEL
  const MIDDLE = ['local.caffeine'];  // shown just left of the clock
  const RIGHT = ['org.kde.plasma.systemtray', 'org.kde.plasma.showdesktop'];
  const all = p.widgets();
  const byId = {};
  all.forEach(w => byId[w.id] = w);

  // Current on-screen order, then anything not listed yet.
  p.currentConfigGroup = ['General'];
  const saved = String(p.readConfig('AppletOrder', '')).split(';').filter(id => byId[id]);
  const order = saved.map(Number).concat(all.map(w => w.id).filter(id => !saved.includes(String(id))));

  const type = id => byId[id].type;
  const left = order.filter(id => !RIGHT.includes(type(id)) && !MIDDLE.includes(type(id)) &&
                                  type(id) !== 'org.kde.plasma.panelspacer' &&
                                  type(id) !== 'org.kde.plasma.digitalclock');
  const spacers = order.filter(id => type(id) === 'org.kde.plasma.panelspacer');
  const clock = order.filter(id => type(id) === 'org.kde.plasma.digitalclock').slice(0, 1);
  const middle = MIDDLE.reduce((acc, t) => acc.concat(order.filter(id => type(id) === t)), []);
  const right = RIGHT.reduce((acc, t) => acc.concat(order.filter(id => type(id) === t)), []);

  const final = left.concat([spacers[0]], middle, clock, [spacers[1]], right);
  const changed = final.join(';') !== String(p.readConfig('AppletOrder', ''));
  if (changed) p.writeConfig('AppletOrder', final.join(';'));
  print((changed ? 'CHANGED ' : 'SAME ') + final.map(id => type(id).replace('org.kde.plasma.', '')).join(', '));
")
echo "${arranged#* }"

echo "Applying clock settings..."
plasma_script "
  $FIND_PANEL
  p.widgets('org.kde.plasma.digitalclock').forEach(w => {
    w.currentConfigGroup = ['Appearance'];
    w.writeConfig('dateDisplayFormat', '$CLOCK_DATE_DISPLAY');
    w.writeConfig('dateFormat', 'custom');
    w.writeConfig('customDateFormat', '$CLOCK_DATE_FORMAT');
    w.writeConfig('autoFontAndSize', true);
  });
" >/dev/null

if [[ $arranged == CHANGED* ]]; then
  echo "Restarting the panel to apply the new order..."
  timeout 90 systemctl --user restart plasma-plasmashell.service ||
    echo "The panel took long to restart; log out and back in if it looks wrong."
else
  echo "Widget order is already right; no panel restart needed."
fi

echo ""
echo "Done. To change the size or position later, edit the values at the top of"
echo "this script and run it again."
