#!/bin/bash
# Make KDE Plasma turn the screen off after 1 minute idle and lock the session
# as it does, so moving the mouse or pressing a key brings up the lock screen.
# If the lock screen is then left alone, KDE turns the screen off again after
# its usual delay. Applies whether plugged in, on battery or on low battery.
#
# Dimming is left at KDE's default (any custom value is removed); it would only
# kick in after the screen is already off, so it has no visible effect.
# Takes effect immediately; no need to log out. Safe to run again.

set -euo pipefail

IDLE_MINUTES=1

echo "Turning the screen off after $IDLE_MINUTES minute(s) idle..."
for profile in AC Battery LowBattery; do
  kwriteconfig6 --file powerdevilrc --group "$profile" --group Display --key TurnOffDisplayWhenIdle true
  kwriteconfig6 --file powerdevilrc --group "$profile" --group Display --key TurnOffDisplayIdleTimeoutSec "$((IDLE_MINUTES * 60))"
  kwriteconfig6 --file powerdevilrc --group "$profile" --group Display --key LockBeforeTurnOffDisplay true
  kwriteconfig6 --file powerdevilrc --group "$profile" --group Display --key TurnOffDisplayIdleTimeoutWhenLockedSec --delete
  kwriteconfig6 --file powerdevilrc --group "$profile" --group Display --key DimDisplayIdleTimeoutSec --delete
done

echo "Locking the screen when it turns off..."
# The screen locker's own idle timer is a fallback, set a minute later so it
# doesn't race the screen turning off.
kwriteconfig6 --file kscreenlockerrc --group Daemon --key Autolock true
kwriteconfig6 --file kscreenlockerrc --group Daemon --key Timeout "$((IDLE_MINUTES + 1))"
# By default, input in the first 5 seconds after locking unlocks without a
# password. Turn that off so waking the screen always shows the lock screen.
kwriteconfig6 --file kscreenlockerrc --group Daemon --key LockGrace 0

# Tell the running power manager and screen locker to reload their settings.
# Skipped quietly when not run inside a Plasma session.
busctl --user call org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement \
  org.kde.Solid.PowerManagement refreshStatus >/dev/null 2>&1 || true
busctl --user call org.kde.screensaver /ScreenSaver \
  org.kde.screensaver configure >/dev/null 2>&1 || true

echo ""
echo "Done. Change these later in System Settings → Power Management and → Screen Locking."
