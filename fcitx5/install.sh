#!/usr/bin/env bash
# fcitx5 setup (Linux only). Runs via `dotfiles setup linux omarchy`,
# `dotfiles setup linux niri` and `dotfiles deps fcitx`. Everything here is
# user-local, no sudo.
#
# `dotfiles link fcitx` already handles the plain symlinks:
#   fcitx5/environment.d/fcitx.conf → ~/.config/environment.d/fcitx.conf
#   fcitx5/conf                     → ~/.config/fcitx5/conf
#   (Omarchy autostarts fcitx5 through omarchy-fcitx5.service; uwsm imports
#   environment.d)
# This script covers what cannot be a symlink:
#   - ~/.config/fcitx5/conf/classicui.conf: seeded from fcitx5/classicui.conf,
#     then pointed at the theme the desktop generates, so the candidate window
#     follows the system theme (Omarchy: `omarchy-theme-set-fcitx5` → `omarchy`,
#     refreshed on every theme switch; nbshell: theme-hook.sh → `Nbshell`).
#     Runtime state — gitignored, because both desktop tools rewrite it in place.
#   - ~/.config/fcitx5/config: patched to disable the kimpanel addon
#   - ~/.local/share/fcitx5/rime: user schema, pulled from the private rime repo
#     (a clean checkout is kept at ~/.local/share/fcitx5/rime-config and an
#     archive of HEAD is exported into the live rime dir, so build/ and user
#     data never touch the checkout)
#   - ~/.config/fcitx5/profile: patched so rime is registered and default IM
set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FCITX_CONFIG_DIR="$CONFIG_HOME/fcitx5"

if ! command -v fcitx5 >/dev/null 2>&1; then
    echo "fcitx5 not installed — skipped fcitx5 setup"
    exit 0
fi

printf '\n== fcitx5 setup ==\n'

# kimpanel is the KDE tray consumer; both Omarchy's classic UI and nbshell want
# fcitx's own candidate window, so the addon stays disabled either way.
mkdir -p "$FCITX_CONFIG_DIR"
python3 - "$FCITX_CONFIG_DIR/config" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text() if path.exists() else "[Behavior]\n"
text = re.sub(r'(?ms)^\[Behavior/DisabledAddons\]\n.*?(?=^\[|\Z)', '', text).rstrip()
path.write_text(text + "\n\n[Behavior/DisabledAddons]\n0=kimpanel\n")
PY

# classicui: seed once, then hand the theme over to whoever generates it. Both
# theme owners only replace a theme that is unset or still stock, so a theme
# picked in fcitx5-configtool survives — mirror that rule here.
classicui="$FCITX_CONFIG_DIR/conf/classicui.conf"
mkdir -p "${classicui%/*}"
if [ ! -e "$classicui" ]; then
    cp "$SCRIPT_DIR/classicui.conf" "$classicui"
fi

# The niri profile also runs on Arch/Omarchy, so the desktop shell decides which
# theme owns the candidate window: `Nbshell` wherever nbshell's config is linked
# (linux niri), otherwise Omarchy's generated `omarchy` theme.
if [ -e "$CONFIG_HOME/nbshell/config.json" ]; then
    # nbshell's theme-hook.sh writes the `Nbshell` theme from palette.sh and
    # reloads classicui; the pointer itself is ours to set. `omarchy` counts as
    # stock here — it was never a deliberate choice on a nbshell desktop.
    python3 - "$classicui" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text() if path.exists() else ""
for key in ("Theme", "DarkTheme"):
    pattern = rf"(?m)^{key}=.*$"
    if not re.search(pattern, text):
        text = text.rstrip() + f"\n{key}=Nbshell\n"
    elif re.search(rf"(?m)^{key}=(?:|default|default-dark|omarchy)$", text):
        text = re.sub(pattern, f"{key}=Nbshell", text, count=1)
path.write_text(text)
PY
elif command -v omarchy-theme-set-fcitx5 >/dev/null 2>&1; then
    # Regenerates ~/.local/share/fcitx5/themes/omarchy from the live palette and
    # points classicui at it. Omarchy runs the same tool on every theme switch,
    # which is what keeps the candidate window in step with the desktop.
    omarchy-theme-set-fcitx5 --activate ||
        echo "omarchy-theme-set-fcitx5 failed — the candidate window keeps its current theme"
fi

if [ ! -f /usr/share/fcitx5/inputmethod/rime.conf ]; then
    echo "fcitx5-rime not installed — skipped rime schema deployment"
    exit 0
fi

rime_dir="$DATA_HOME/fcitx5/rime"
rime_source="$DATA_HOME/fcitx5/rime-config"
rime_repo=https://github.com/aBER0724/rime.git
if [[ -d "$rime_source/.git" ]]; then
    git -C "$rime_source" pull --ff-only || true
else
    rm -rf "$rime_source"
    git clone --depth=1 "$rime_repo" "$rime_source"
fi
mkdir -p "$rime_dir"
git -C "$rime_source" archive HEAD | tar -x -C "$rime_dir"

python3 - "$FCITX_CONFIG_DIR/profile" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text() if path.exists() else ""
if "Name=rime" not in text:
    item_numbers = [int(value) for value in re.findall(r"(?m)^\[Groups/0/Items/(\d+)\]$", text)]
    index = max(item_numbers, default=-1) + 1
    text = text.rstrip() + f"\n\n[Groups/0/Items/{index}]\nName=rime\nLayout=\n"
if re.search(r"(?m)^DefaultIM=.*$", text):
    text = re.sub(r"(?m)^DefaultIM=.*$", "DefaultIM=rime", text, count=1)
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(text.lstrip())
PY

python3 "$SCRIPT_DIR/rime-lua-compat.py"
