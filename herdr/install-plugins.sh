#!/bin/bash
# Install all herdr plugins listed in plugins.txt on a new device.
# GitHub plugins are installed at their pinned ref; local plugins are linked.
# Run:  bash ~/dotfiles/herdr/install-plugins.sh
set -euo pipefail

PLUGINS="$HOME/dotfiles/herdr/plugins.txt"
SCRATCH="$HOME/dotfiles/herdr/scratch"

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
if ! command -v tmux >/dev/null 2>&1; then
  echo "warning: 'tmux' not found — herdr requires tmux to keep sessions alive."
  echo "         install it first, e.g. 'brew install tmux' / 'apt install tmux'"
fi

FAILED=""
echo "== Installing GitHub plugins =="
while IFS='|' read -r id kind cmd; do
  if [ "$kind" = "github" ]; then
    printf '  %s ... ' "$id"
    # eval is intentional: cmd carries `--ref` args from the inventory.
    if eval "$cmd -y" >/dev/null 2>&1; then
      echo "ok"
    else
      echo "FAILED"
      FAILED="$FAILED $id"
    fi
  else
    echo "  $id (local, linked via scratch)"
  fi
done < "$PLUGINS"

echo "== Linking local plugins =="
if [ -d "$SCRATCH" ]; then
  mkdir -p ~/.local/share
  ln -sfn "$SCRATCH" ~/.local/share/herdr-scratch
  # `herdr plugin link` runs no [[build]] steps, so the checkout needs its
  # binary in place. Point it at the brew-installed herdr-scratch.
  mkdir -p "$SCRATCH/bin"
  ln -sfn "$(command -v herdr-scratch)" "$SCRATCH/bin/herdr-scratch"
  herdr plugin link ~/.local/share/herdr-scratch
fi

if [ -n "$FAILED" ]; then
  echo
  echo "WARNING: failed to install:$FAILED"
  echo "  Most likely missing build deps (go, rust, ...). Fix and re-run:"
  echo "  bash ~/dotfiles/herdr/install-plugins.sh"
  exit 1
fi

echo "done"