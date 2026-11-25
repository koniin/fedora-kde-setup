#!/bin/bash
# Add a "usb-dock-reset" command that recovers the ThinkPad USB-C dock when its
# USB controller dies (kernel log: "xHCI host controller not responding,
# assume dead" / "HC died"), which kills the keyboard, mouse and dock network.
#
# Installs (for your user only, no sudo):
#   ~/.local/bin/usb-dock-reset   [PCI address]   (asks for your sudo password)
#
# What it does:
#   1. Unbinds and rebinds the USB controller (default 0000:c5:00.4, the one
#      the dock hangs off on the T14s Gen 4). Works whether or not the
#      controller is still bound. If rebinding fails, it removes the device
#      from the PCI bus and rescans instead.
#   2. Waits for the Logitech receiver (046d:c53f) to come back and resets it,
#      so it pairs with the mouse again (otherwise the mouse stays dead).
#
# Safe to run again.

set -euo pipefail

HELPER="$HOME/.local/bin/usb-dock-reset"

echo "Installing usb-dock-reset..."
mkdir -p "$(dirname "$HELPER")"
cat >"$HELPER" <<'HELPER'
#!/bin/bash
# usb-dock-reset: recover a dead USB controller and the devices behind it.
# Usage: usb-dock-reset [PCI address]   (default 0000:c5:00.4)

set -uo pipefail

PCI="${1:-0000:c5:00.4}"
DRIVER=/sys/bus/pci/drivers/xhci_hcd
DEV=/sys/bus/pci/devices/$PCI
RECEIVERS=("046d:c53f")   # USB receivers to reset afterwards (vendor:product)

if [[ ! -e $DEV ]]; then
  echo "No PCI device $PCI; trying a PCI rescan."
  echo 1 | sudo tee /sys/bus/pci/rescan >/dev/null
  sleep 3
  [[ -e $DEV ]] || { echo "Still no $PCI. Reboot needed." >&2; exit 1; }
fi

sudo -v || exit 1

if [[ -e $DEV/driver ]]; then
  echo "Unbinding USB controller $PCI..."
  echo "$PCI" | sudo tee "$DRIVER/unbind" >/dev/null
  sleep 2
fi

echo "Binding USB controller $PCI..."
if ! echo "$PCI" | sudo tee "$DRIVER/bind" >/dev/null 2>&1 || [[ ! -e $DEV/driver ]]; then
  echo "Bind failed; removing the controller from the PCI bus and rescanning..."
  echo 1 | sudo tee "$DEV/remove" >/dev/null
  sleep 2
  echo 1 | sudo tee /sys/bus/pci/rescan >/dev/null
  sleep 3
  if [[ ! -e $DEV/driver ]]; then
    echo "The controller didn't come back. Try suspend/resume or a reboot." >&2
    exit 1
  fi
fi

# Find a USB device by vendor:product under this controller.
find_usb() {
  local vid=${1%:*} pid=${1#*:} d
  for d in /sys/bus/usb/devices/*; do
    [[ -f $d/idVendor && -f $d/idProduct ]] || continue
    [[ $(<"$d/idVendor") == "$vid" && $(<"$d/idProduct") == "$pid" ]] || continue
    [[ $(readlink -f "$d") == *"/$PCI/"* ]] && echo "$d"
  done
}

for id in "${RECEIVERS[@]}"; do
  found=
  for _ in $(seq 1 15); do       # devices behind the dock take a few seconds
    found=$(find_usb "$id")
    [[ -n $found ]] && break
    sleep 1
  done
  if [[ -z $found ]]; then
    echo "Receiver $id didn't show up; skipping it."
    continue
  fi
  for d in $found; do
    echo "Resetting receiver $id ($(basename "$d"))..."
    echo 0 | sudo tee "$d/authorized" >/dev/null
    sleep 1
    echo 1 | sudo tee "$d/authorized" >/dev/null
  done
done

echo "Done. Click a mouse button if the mouse doesn't move straight away."
HELPER
chmod +x "$HELPER"

echo "Installed $HELPER"
echo "Run 'usb-dock-reset' when the dock's keyboard/mouse/network stop working."
