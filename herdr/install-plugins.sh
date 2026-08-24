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

echo "== Installing GitHub plugins =="
while IFS='|' read -r id kind cmd; do
  if [ "$kind" = "github" ]; then
    echo "  $id ..."
    # eval is intentional: cmd carries `--ref` args from the inventory.
    eval "$cmd -y"
  else
    echo "  $id (local, linked via scratch)"
  fi
done < "$PLUGINS"

echo "== Linking local plugins =="
if [ -d "$SCRATCH" ]; then
  mkdir -p ~/.local/share
  ln -sfn "$SCRATCH" ~/.local/share/herdr-scratch
  herdr plugin link ~/.local/share/herdr-scratch
fi

echo "done"