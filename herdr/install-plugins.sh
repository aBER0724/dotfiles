#!/bin/bash
# Install all herdr plugins listed in plugins.txt on a new device.
# GitHub plugins are installed at their pinned ref when one is specified.
# Run:  bash ~/dotfiles/herdr/install-plugins.sh
set -euo pipefail

PLUGINS="$HOME/dotfiles/herdr/plugins.txt"
HOST_UNAME="${DOTFILES_UNAME:-$(uname -s)}"

if ! command -v herdr >/dev/null 2>&1; then
  echo "error: herdr not installed. Run: brew install herdr" >&2
  exit 1
fi
if [ ! -f "$PLUGINS" ]; then
  echo "error: $PLUGINS not found" >&2
  exit 1
fi

# Some GitHub plugins have a build step (Go/Rust/...). Warn up front so a
# missing toolchain fails clearly instead of as a confusing per-plugin error.
if ! command -v go >/dev/null 2>&1; then
  echo "warning: 'go' not found — plugins with a Go build step will fail."
  echo "         install it first, e.g. 'brew install go' / 'apt install golang-go'"
fi
if ! command -v cargo >/dev/null 2>&1; then
  echo "warning: 'cargo' not found — Rust plugins will fail to build."
  echo "         install it first, e.g. 'brew install rust' / 'pacman -S rust'"
fi
if ! command -v yazi >/dev/null 2>&1; then
  echo "warning: 'yazi' not found — the ray.file-explorer plugin will fail."
  echo "         install it first, e.g. 'brew install yazi' / 'pacman -S yazi'"
fi
if ! command -v tmux >/dev/null 2>&1; then
  echo "warning: 'tmux' not found — herdr requires tmux to keep sessions alive."
  echo "         install it first, e.g. 'brew install tmux' / 'apt install tmux'"
fi

FAILED=""
echo "== Installing GitHub plugins =="
while IFS='|' read -r id kind cmd; do
  if [ "$kind" = "github-linux" ] && [ "$HOST_UNAME" = Darwin ]; then
    echo "  $id (provided by the macOS Homebrew cask)"
  elif [ "$kind" = "github" ] || [ "$kind" = "github-linux" ]; then
    LOG_FILE="$(mktemp "${TMPDIR:-/tmp}/herdr-plugin.XXXXXX")"
    printf '  %s ... ' "$id"
    # eval is intentional: cmd carries `--ref` args from the inventory.
    if eval "$cmd -y" >"$LOG_FILE" 2>&1; then
      echo "ok"
      rm -f -- "$LOG_FILE"
    else
      echo "FAILED"
      sed 's/^/    | /' "$LOG_FILE"
      rm -f -- "$LOG_FILE"
      FAILED="$FAILED $id"
    fi
  else
    echo "  $id (unsupported inventory kind: $kind)"
    FAILED="$FAILED $id"
  fi
done < "$PLUGINS"
if [ -n "$FAILED" ]; then
  echo
  echo "WARNING: failed to install:$FAILED"
  echo "  Review the per-plugin logs above, install the reported dependency, and re-run:"
  echo "  bash ~/dotfiles/herdr/install-plugins.sh"
  exit 1
fi

echo "done"