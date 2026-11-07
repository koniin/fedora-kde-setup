#!/bin/bash
# Install and set up everything in this repo, in the right order.
#
#   ./run-all.sh                    run every step
#   ./run-all.sh --list             show the steps in order
#   ./run-all.sh --from STEP        start at STEP (e.g. to carry on after a failure)
#   ./run-all.sh --only STEP...     run only these steps (still in the order below)
#   ./run-all.sh --skip STEP...     run everything except these steps
#
# STEP is a script name, with or without ".sh" (e.g. install-steam).
#
# Every script checks what's already done and skips it, so running this again
# only changes what's missing or out of date. If a step fails, the rest still
# run and the failures are listed at the end; fix the cause and run again.
#
# Run it from inside a KDE Plasma session as your normal user (not root);
# it asks for your sudo password once at the start. Apps aren't opened while
# it runs (NO_LAUNCH=1); find them in the app menu afterwards.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# The order matters:
#   - git first: installs git/gh and asks for the GitHub login while you're
#     still at the keyboard.
#   - codecs before Steam: both use RPM Fusion; codecs adds the free repo.
#   - the font before the theme (the login screen copies your fonts), foot and
#     the shell prompt (both use its icons).
#   - foot before the shortcuts (Meta+Return opens foot if it's installed).
#   - caffeine before the panel (the panel puts the cup next to the clock).
#   - mise before the dev environment that uses it.
#   - Firefox's setting last-ish: by then Firefox (and its profile) exist.
STEPS=(
  setup-git                        # git name/email, GitHub login
  install-codecs                   # RPM Fusion free, full ffmpeg, VA-API driver
  setup-kde-font                   # JetBrainsMono Nerd Font everywhere
  setup-kde-henke                  # Nord theme, Henke global theme, wallpaper, login screen
  setup-kde-desktops               # 5 virtual desktops, Meta+1..5
  install-foot                     # foot terminal (default terminal)
  setup-kde-shortcuts              # omarchy-style shortcuts
  setup-kde-screen-timeouts        # screen off + lock after 1 minute
  install-kde-caffeine             # stay-awake panel button
  setup-kde-panel                  # panel layout, clock in the middle
  setup-shell-prompt               # starship, eza, zoxide, fzf
  install-mise                     # language version manager
  setup-henke-dev-env              # Node LTS, Bun, .NET via mise
  install-claude                   # Claude Code CLI
  install-codex                    # Codex CLI
  install-vscode                   # VS Code + Nord theme
  install-1password                # 1Password + browser extensions
  install-spotify                  # Spotify
  install-steam                    # Steam (RPM Fusion)
  install-godot                    # Godot
  install-bambu-studio             # Bambu Studio
  install-tresorit                 # Tresorit + ~/Cloud
  setup-firefox-restore-session    # Firefox reopens your tabs
  setup-usb-dock-reset             # usb-dock-reset command
)

# Scripts that are run by another step rather than on their own.
RUN_BY_OTHERS=(
  install-dev-env          # by setup-henke-dev-env (needs arguments)
  setup-kde-nord-theme     # by setup-kde-henke (through setup-kde-henke-theme)
  setup-kde-henke-theme    # by setup-kde-henke
  setup-kde-wallpaper      # by setup-kde-henke
  setup-kde-nord-login     # by setup-kde-henke
)

usage() {
  sed -n '2,/^$/{s/^# \{0,1\}//;p}' "$0"
  exit "${1:-0}"
}

in_list() {
  local want=$1 item
  shift
  for item in "$@"; do [[ $item == "$want" ]] && return 0; done
  return 1
}

known_step() {
  in_list "$1" "${STEPS[@]}" && return 0
  echo "Unknown step: $1 (see ./run-all.sh --list)" >&2
  exit 1
}

list_steps() {
  local i
  for i in "${!STEPS[@]}"; do
    printf '%2d. %s\n' $((i + 1)) "${STEPS[$i]}"
  done
}

# Warn about scripts that were added to the repo but not to STEPS.
check_unlisted() {
  local f name
  for f in "$SCRIPT_DIR"/install-*.sh "$SCRIPT_DIR"/setup-*.sh; do
    name=$(basename "$f" .sh)
    in_list "$name" "${STEPS[@]}" "${RUN_BY_OTHERS[@]}" && continue
    echo "Warning: $name.sh isn't in run-all.sh's STEPS, so it won't run." >&2
  done
}

# --- arguments ---
mode=all
from=""
selected=()
while (($#)); do
  case "$1" in
    -h | --help) usage ;;
    --list) list_steps; exit 0 ;;
    --from)
      [[ -n ${2:-} ]] || usage 1
      from=${2%.sh}; known_step "$from"; shift 2 ;;
    --only | --skip)
      mode=${1#--}; shift
      while (($#)) && [[ $1 != --* ]]; do
        known_step "${1%.sh}"; selected+=("${1%.sh}"); shift
      done
      ((${#selected[@]})) || usage 1
      ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

# --- what to run ---
plan=()
started=$([[ -z $from ]] && echo true || echo false)
for step in "${STEPS[@]}"; do
  [[ $step == "$from" ]] && started=true
  $started || continue
  case $mode in
    only) in_list "$step" "${selected[@]}" || continue ;;
    skip) in_list "$step" "${selected[@]}" && continue ;;
  esac
  plan+=("$step")
done

# --- checks ---
if ((EUID == 0)); then
  echo "Run this as your normal user, not root; it uses sudo where needed." >&2
  exit 1
fi
if ! grep -qi '^ID=fedora' /etc/os-release 2>/dev/null; then
  echo "This is meant for Fedora." >&2
  exit 1
fi
if [[ ${XDG_CURRENT_DESKTOP:-} != *KDE* ]]; then
  echo "Warning: not in a KDE Plasma session; the KDE steps will fail." >&2
fi
check_unlisted

# User-level tools (mise, starship, claude, ...) go in ~/.local/bin; make sure
# later steps find what earlier steps installed.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
export NO_LAUNCH=1

echo "Will run ${#plan[@]} step(s):"
printf '  %s\n' "${plan[@]}"
echo ""

# Ask for the sudo password once and keep it fresh while the steps run.
sudo -v || exit 1
while true; do
  sudo -n true 2>/dev/null
  sleep 50
  kill -0 $$ 2>/dev/null || exit
done &
KEEPALIVE=$!
trap 'kill "$KEEPALIVE" 2>/dev/null' EXIT

# --- run ---
ok=()
failed=()
total=${#plan[@]}
n=0
for step in "${plan[@]}"; do
  n=$((n + 1))
  echo ""
  echo "==================== [$n/$total] $step ===================="
  if "$SCRIPT_DIR/$step.sh"; then
    ok+=("$step")
  else
    echo ">>> $step failed (exit code $?)." >&2
    failed+=("$step")
  fi
done

# --- summary ---
echo ""
echo "==================== Summary ===================="
echo "Done: ${#ok[@]}/$total"
if ((${#failed[@]})); then
  echo "Failed:"
  printf '  %s\n' "${failed[@]}"
  echo ""
  echo "Fix the cause (see the output above) and run ./run-all.sh again, or just"
  echo "the failed steps: ./run-all.sh --only ${failed[*]}"
  exit 1
fi
echo ""
echo "Everything is set up. Log out and back in to see all the changes."
