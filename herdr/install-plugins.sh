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

# These are required by entries in plugins.txt. Stop before attempting known
# failures and route through the platform-aware dotfiles dependency installer.
MISSING_DEPS=""
for dep in go cargo yazi tmux; do
  command -v "$dep" >/dev/null 2>&1 || MISSING_DEPS="$MISSING_DEPS $dep"
done
if [ -n "$MISSING_DEPS" ]; then
  echo "error: missing required herdr plugin dependencies:$MISSING_DEPS" >&2
  echo "Install them and retry with:" >&2
  echo "  bash ~/dotfiles/bin/dotfiles deps herdr" >&2
  exit 1
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