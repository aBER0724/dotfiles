#!/bin/bash
# Regenerate herdr/plugins.txt from herdr's installed plugin state.
# Run after installing/removing a herdr plugin so other devices can reinstall
# the exact same set:  bash ~/dotfiles/herdr/gen-plugins.sh
set -euo pipefail

PLUGINS_JSON="$HOME/.config/herdr/plugins.json"
# Write the inventory next to this script: the checkout can live anywhere.
OUT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/plugins.txt"

if [ ! -f "$PLUGINS_JSON" ]; then
  echo "error: $PLUGINS_JSON not found" >&2
  exit 1
fi

# Keep deliberate kinds from the previous inventory: herdr reports user.scratch
# as a plain github source, but it is tracked as `github-linux` on purpose so
# Linux rebuilds it from the current upstream instead of a pinned ref.
OLD_KINDS=""
[ -f "$OUT" ] && OLD_KINDS="$(cut -d'|' -f1,2 "$OUT" | tr '\n' ' ')"

python3 - "$PLUGINS_JSON" "$OLD_KINDS" > "$OUT" <<'EOF'
import json, sys

plugins = json.load(open(sys.argv[1]))
old = dict(item.split('|', 1) for item in sys.argv[2].split() if '|' in item)
for p in plugins:
    src = p.get("source", {})
    pid = p["plugin_id"]
    kind = src.get("kind", "unknown")
    if old.get(pid) == "github-linux" and kind == "github":
        kind = "github-linux"
    if kind in ("github", "github-linux"):
        cmd = f'herdr plugin install {src["owner"]}/{src["repo"]}'
        if kind == "github":
            ref = src.get("requested_ref") or src.get("resolved_commit", "")
            if ref:
                cmd += f" --ref {ref}"
        print(f"{pid}|{kind}|{cmd}")
    else:
        print(f"{pid}|{kind}|herdr plugin link <path>")
EOF

echo "wrote $OUT ($(wc -l < "$OUT") plugins)"