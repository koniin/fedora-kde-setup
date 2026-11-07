#!/bin/bash
# Omarchy's terminal prompt, ls, cd (zoxide) and fzf search for bash.
#
# Prompt: Starship with Omarchy's config (config/starship.toml): the last two
# folders of the path, the git branch and status, and a cyan ❯ that turns into
# ✗ when a command fails. The prompt also starts with an empty line.
#
# ls: eza, with Omarchy's aliases (default/bash/aliases):
#   ls    long list, readable sizes, folders first, icons
#   lsa   the same, including hidden files
#   lt    tree two levels deep, with git status
#   lta   the same, including hidden files
#
# zoxide, with Omarchy's cd (default/bash/aliases): cd works as usual, but if
# the folder doesn't exist it jumps to the best match from folders you've
# visited before, e.g. "cd sys" -> ~/Projects/system-install. "zi" picks
# interactively.
#
# fzf, with Omarchy's key bindings (default/bash/init):
#   Ctrl+R   search command history
#   Ctrl+T   insert a file path
#   Alt+C    cd into a folder
#   ff       find a file with a preview (bat), prints its path
#   eff      find a file and open it in $EDITOR
#
# History and completion, from Omarchy's default/bash/shell and inputrc:
#   - 32768 commands of history, appended rather than overwritten, so several
#     terminals don't wipe each other's history; duplicates and commands
#     starting with a space aren't saved.
#   - Up/Down search history for what you've typed so far ("git" + Up finds
#     your last git command).
#   - Tab cycles through matches (Shift+Tab goes back), shows them all at once,
#     ignores case, colors them like ls, and skips hidden files unless you type
#     the dot.
#
# The readline settings go in ~/.config/bash/inputrc, loaded on top of Fedora's
# /etc/inputrc, so ~/.inputrc is left alone.
#
# Starship isn't packaged by Fedora, so the official release is downloaded,
# checked against its checksum and installed to ~/.local/bin. eza, zoxide, fzf
# and bat come from dnf.
# The shell setup goes in ~/.bashrc.d/omarchy-prompt.sh, which Fedora's .bashrc
# loads. Icons need a Nerd Font, like the one from setup-kde-font.sh.
# A starship.toml that differs from this one is backed up to starship.toml.bak
# first. Safe to run again.

set -euo pipefail

BIN_DIR="$HOME/.local/bin"
STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
BASHRC_SNIPPET="$HOME/.bashrc.d/omarchy-prompt.sh"
# Not in ~/.bashrc.d: everything there is sourced as bash.
INPUTRC_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/bash/inputrc"
RELEASE="https://github.com/starship/starship/releases/latest/download"

MISSING=()
for pkg in eza zoxide fzf bat; do
  command -v "$pkg" >/dev/null || MISSING+=("$pkg")
done
if ((${#MISSING[@]})); then
  echo "Installing ${MISSING[*]}..."
  sudo dnf install -y "${MISSING[@]}"
else
  echo "eza, zoxide, fzf and bat are already installed."
fi

if command -v starship >/dev/null; then
  echo "Starship is already installed."
else
  echo "Downloading Starship..."
  ARCHIVE="starship-$(uname -m)-unknown-linux-musl.tar.gz"
  WORK=$(mktemp -d)
  trap 'rm -rf "$WORK"' EXIT
  curl -fL --progress-bar "$RELEASE/$ARCHIVE" -o "$WORK/$ARCHIVE"
  HASH=$(curl -fsSL "$RELEASE/$ARCHIVE.sha256")

  echo "Verifying checksum..."
  (cd "$WORK" && echo "$HASH  $ARCHIVE" | sha256sum -c --quiet -)

  echo "Installing to $BIN_DIR..."
  tar -xzf "$WORK/$ARCHIVE" -C "$WORK" starship
  mkdir -p "$BIN_DIR"
  install -m 755 "$WORK/starship" "$BIN_DIR/starship"
fi

mkdir -p "$(dirname "$STARSHIP_CONFIG")"
NEW_TOML=$(mktemp)
# Replaces the trap above (if set), so clean up both temp paths.
trap 'rm -rf "${WORK:-}" "$NEW_TOML"' EXIT
# The \u escapes are Nerd Font icons: conflict, check mark and pencil.
cat >"$NEW_TOML" <<'TOML'
add_newline = true
command_timeout = 200
format = "[$directory$git_branch$git_status]($style)$character"

[character]
error_symbol = "[✗](bold cyan)"
success_symbol = "[❯](bold cyan)"

[directory]
truncation_length = 2
truncation_symbol = "…/"
repo_root_style = "bold cyan"
repo_root_format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) "

[git_branch]
format = "[$branch]($style) "
style = "italic cyan"

[git_status]
format     = '[$all_status]($style)'
style      = "cyan"
ahead      = "⇡${count} "
diverged   = "⇕⇡${ahead_count}⇣${behind_count} "
behind     = "⇣${count} "
conflicted = " "
up_to_date = " "
untracked  = "? "
modified   = " "
stashed    = ""
staged     = ""
renamed    = ""
deleted    = ""
TOML

# Back up only a config that isn't already ours, so running this again doesn't
# overwrite the backup of your original with a copy of this script's config.
if [[ -f $STARSHIP_CONFIG ]] && ! cmp -s "$NEW_TOML" "$STARSHIP_CONFIG"; then
  cp "$STARSHIP_CONFIG" "$STARSHIP_CONFIG.bak"
  echo "Backed up your old config to $STARSHIP_CONFIG.bak"
fi
echo "Writing $STARSHIP_CONFIG..."
install -m 644 "$NEW_TOML" "$STARSHIP_CONFIG"

echo "Writing $INPUTRC_FILE..."
mkdir -p "$(dirname "$INPUTRC_FILE")"
cat >"$INPUTRC_FILE" <<'INPUTRC'
# Omarchy's readline settings (from setup-shell-prompt.sh), loaded by
# ~/.bashrc.d/omarchy-prompt.sh.
set meta-flag on
set input-meta on
set output-meta on
set convert-meta off
set completion-ignore-case on
set completion-prefix-display-length 2
set show-all-if-ambiguous on
set show-all-if-unmodified on

# Arrow keys match what you've typed so far against your command history
"\e[A": history-search-backward
"\e[B": history-search-forward
"\e[C": forward-char
"\e[D": backward-char

# Immediately add a trailing slash when autocompleting symlinks to directories
set mark-symlinked-directories on

# Do not autocomplete hidden files unless the pattern explicitly begins with a dot
set match-hidden-files off

# Show all autocomplete results at once
set page-completions off

# If there are more than 200 possible completions for a word, ask to show them all
set completion-query-items 200

# Show extra file information when completing, like `ls -F` does
set visible-stats on

# Also look at the text after the cursor when completing
set skip-completed-text on

# Color tab completions like ls
set colored-stats on

# Cycle forward and backward through completion candidates (Tab/Shift+Tab)
TAB: menu-complete
"\e[Z": menu-complete-backward

# On first Tab, complete the common prefix before cycling candidates
set menu-complete-display-prefix on
INPUTRC

echo "Writing $BASHRC_SNIPPET..."
mkdir -p "$(dirname "$BASHRC_SNIPPET")"
cat >"$BASHRC_SNIPPET" <<'BASH'
# Omarchy's prompt, ls, cd, fzf, history and completion (from setup-shell-prompt.sh).
[[ $- == *i* ]] || return 0

# History
shopt -s histappend
HISTCONTROL=ignoreboth
HISTSIZE=32768
HISTFILESIZE="${HISTSIZE}"

# Completion (Fedora normally loads this already)
if [[ ! -v BASH_COMPLETION_VERSINFO && -f /usr/share/bash-completion/bash_completion ]]; then
  source /usr/share/bash-completion/bash_completion
fi

# Readline: history search on Up/Down, Tab cycling, case-insensitive completion
INPUTRC_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/bash/inputrc"
[[ -f $INPUTRC_FILE ]] && bind -f "$INPUTRC_FILE"
unset INPUTRC_FILE

if command -v eza &>/dev/null; then
  alias ls='eza -lh --group-directories-first --icons=auto'
  alias lsa='ls -a'
  alias lt='eza --tree --level=2 --long --icons --git'
  alias lta='lt -a'
fi

# cd into a folder if it exists, otherwise jump to zoxide's best match.
if command -v zoxide &>/dev/null; then
  eval "$(zoxide init bash)"
  alias cd="zd"
  zd() {
    if (( $# == 0 )); then
      builtin cd ~ || return
    elif [[ -d $1 ]]; then
      builtin cd "$1" || return
    else
      if ! z "$@"; then
        echo "Error: Directory not found"
        return 1
      fi

      printf "\U000F17A9 "
      pwd
    fi
  }
fi

# Only the key bindings (Ctrl+R, Ctrl+T, Alt+C), like Omarchy.
if command -v fzf &>/dev/null; then
  [[ -f /usr/share/fzf/shell/key-bindings.bash ]] && source /usr/share/fzf/shell/key-bindings.bash
  alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
  alias eff='${EDITOR:-nano} "$(ff)"'
fi

if [[ ${TERM:-} != "dumb" ]] && command -v starship &>/dev/null; then
  eval "$(starship init bash --print-full-init)"
fi
BASH

echo ""
echo "Done. Open a new terminal, or run: source ~/.bashrc"
