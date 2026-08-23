#!/bin/bash
# Regenerate herdr/plugins.txt from herdr's installed plugin state.
# Run after installing/removing a herdr plugin so other devices can reinstall
# the exact same set:  bash ~/dotfiles/herdr/gen-plugins.sh
set -euo pipefail

PLUGINS_JSON="$HOME/.config/herdr/plugins.json"
OUT="$HOME/dotfiles/herdr/plugins.txt"

if [ ! -f "$PLUGINS_JSON" ]; then
  echo "error: $PLUGINS_JSON not found" >&2
  exit 1
fi

python3 - "$PLUGINS_JSON" > "$OUT" <<'EOF'
import json, sys

plugins = json.load(open(sys.argv[1]))
for p in plugins:
    src = p.get("source", {})
    pid = p["plugin_id"]
    kind = src.get("kind", "unknown")
    if kind == "github":
        ref = src.get("requested_ref") or src.get("resolved_commit", "")
        cmd = f'herdr plugin install {src["owner"]}/{src["repo"]}'
        if ref:
            cmd += f" --ref {ref}"
        print(f"{pid}|{kind}|{cmd}")
    else:
        print(f"{pid}|{kind}|herdr plugin link <path>")
EOF

echo "wrote $OUT ($(wc -l < "$OUT") plugins)"