#!/bin/bash
# Make Firefox remember all open windows and tabs when it's closed, and
# reopen them on the next start (Settings > General > "Open previous windows
# and tabs").
#
# The setting is written to user.js in every Firefox profile, which Firefox
# reads on each start, so it sticks even if prefs.js gets reset. Covers the
# current (~/.config/mozilla), legacy (~/.mozilla) and Flatpak profile folders.
# Restart Firefox to pick it up. If Firefox has never been started, it's
# started once in the background (no window) to create its profile.
# Safe to run again.

set -euo pipefail

PROFILE_ROOTS=(
  "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox"
  "$HOME/.mozilla/firefox"
  "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
  "$HOME/.var/app/org.mozilla.firefox/config/mozilla/firefox"
)

# pref NAME VALUE
PREFS=(
  # 3 = open previous windows and tabs (1 = home page, 0 = blank page)
  "browser.startup.page 3"
  # Also bring the tabs back after a crash or forced shutdown
  "browser.sessionstore.resume_from_crash true"
)

# set_pref FILE NAME VALUE: add or replace user_pref("NAME", VALUE); in FILE.
set_pref() {
  local file=$1 name=$2 value=$3
  local line="user_pref(\"$name\", $value);"
  touch "$file"
  if grep -qF "user_pref(\"$name\"," "$file"; then
    local tmp
    tmp=$(mktemp)
    grep -vF "user_pref(\"$name\"," "$file" >"$tmp" || true
    echo "$line" >>"$tmp"
    cat "$tmp" >"$file"
    rm -f "$tmp"
  else
    echo "$line" >>"$file"
  fi
}

have_profile() {
  local root
  for root in "${PROFILE_ROOTS[@]}"; do
    [[ -f $root/profiles.ini ]] && return 0
  done
  return 1
}

# A fresh install has no profile until Firefox starts once. A short headless
# start creates the default profile without opening a window.
if ! have_profile && command -v firefox >/dev/null; then
  echo "Firefox has no profile yet; starting it once in the background to create one..."
  timeout 20 firefox --headless about:blank >/dev/null 2>&1 || true
  sleep 1
fi

found=0
for root in "${PROFILE_ROOTS[@]}"; do
  [[ -f $root/profiles.ini ]] || continue
  # Profile paths from profiles.ini; relative ones live under $root.
  while IFS='|' read -r path relative; do
    [[ $relative == 1 ]] && dir="$root/$path" || dir="$path"
    [[ -d $dir ]] || continue
    found=1
    echo "Updating $dir/user.js..."
    for pref in "${PREFS[@]}"; do
      set_pref "$dir/user.js" $pref
    done
    # Clearing history on shutdown also wipes the saved session.
    if grep -qF 'user_pref("privacy.sanitize.sanitizeOnShutdown", true);' "$dir/prefs.js" 2>/dev/null; then
      echo "  Note: this profile clears history when Firefox closes, which can discard"
      echo "  the saved tabs. Turn it off under Settings > Privacy & Security > History."
    fi
  done < <(awk -F= '
    /^\[/          { if (p != "") print p "|" r; p = ""; r = 1 }
    $1 == "Path"       { p = substr($0, 6) }
    $1 == "IsRelative" { r = $2 }
    END            { if (p != "") print p "|" r }
  ' "$root/profiles.ini")
done

if ((found == 0)); then
  echo "No Firefox profiles found. Start Firefox once to create one, then run this again." >&2
  exit 1
fi

echo ""
if pgrep -x firefox >/dev/null || pgrep -f 'firefox-bin|org.mozilla.firefox' >/dev/null; then
  echo "Done. Firefox is running; restart it to apply the setting."
else
  echo "Done. Firefox will reopen your windows and tabs from now on."
fi
