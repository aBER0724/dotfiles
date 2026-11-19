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
#   - ~/.config/fcitx5/profile: patched to hold rime alone (Fcitx's native
#     keyboard layouts are dropped) as the default and only engine
set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FCITX_CONFIG_DIR="$CONFIG_HOME/fcitx5"
FCITX_UNIT=omarchy-fcitx5.service

if ! command -v fcitx5 >/dev/null 2>&1; then
    echo "fcitx5 not installed — skipped fcitx5 setup"
    exit 0
fi

printf '\n== fcitx5 setup ==\n'

fcitx_managed_by_unit() {
    systemctl --user is-active --quiet "$FCITX_UNIT" 2>/dev/null
}

fcitx_daemon_pid() {
    pgrep -u "$(id -u)" -x fcitx5 2>/dev/null || true
}

fcitx_is_running() {
    fcitx_managed_by_unit || [ -n "$(fcitx_daemon_pid)" ]
}

# fcitx5 owns ~/.config/fcitx5/profile while it runs: on exit it writes its
# in-memory profile over the file, so an edit made underneath a live daemon is
# lost (rime would simply never be registered). Stop it, patch, start it again
# the same way it was running.
fcitx_stop() {
    if fcitx_managed_by_unit; then
        systemctl --user stop "$FCITX_UNIT"
    else
        fcitx5-remote -e >/dev/null 2>&1 || pkill -u "$(id -u)" -x fcitx5 || true
    fi
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        if [ -z "$(fcitx_daemon_pid)" ]; then return 0; fi
        sleep 0.1
    done
}

fcitx_start() {
    case "$1" in
        unit) systemctl --user start "$FCITX_UNIT" ;;
        daemon) fcitx5 -d --replace >/dev/null 2>&1 || true ;;
    esac
}

fcitx_mode=none
if fcitx_managed_by_unit; then
    fcitx_mode=unit
elif [ -n "$(fcitx_daemon_pid)" ]; then
    fcitx_mode=daemon
fi

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
else
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

    if [ "$fcitx_mode" != none ]; then
        fcitx_stop
    fi

    # Rime is the only engine: register it in the default group, drop Fcitx's own
    # keyboard layouts (the "native English" input method), and make rime the
    # activated engine. Latin input comes from rime's ascii mode, so Super+I and
    # Ctrl+Space no longer alternate between two engines. Item blocks go before
    # [GroupOrder] so the file keeps fcitx's own shape.
    python3 - "$FCITX_CONFIG_DIR/profile" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text() if path.exists() else ""
if not text.strip():
    text = (
        "[Groups/0]\nName=Default\nDefault Layout=us\nDefaultIM=rime\n\n"
        "[GroupOrder]\n0=Default\n"
    )


def item_name(body):
    match = re.search(r"(?m)^Name=(.*)$", body)
    return match.group(1).strip() if match else ""


items = [
    body
    for _, body in re.findall(r"(?ms)^\[Groups/0/Items/(\d+)\]\n(.*?)(?=^\[|\Z)", text)
    if not item_name(body).startswith("keyboard-")
]
if not any(item_name(body) == "rime" for body in items):
    items.append("Name=rime\nLayout=\n")

text = re.sub(r"(?ms)^\[Groups/0/Items/\d+\]\n.*?(?=^\[|\Z)", "", text)
text = re.sub(r"\n{3,}", "\n\n", text)
block = "".join(
    f"[Groups/0/Items/{number}]\n{body.rstrip()}\n\n"
    for number, body in enumerate(items)
)
if re.search(r"(?m)^\[GroupOrder\]$", text):
    text = re.sub(r"(?m)^\[GroupOrder\]$", block + "[GroupOrder]", text, count=1)
else:
    text = text.rstrip() + "\n\n" + block.rstrip() + "\n"
if re.search(r"(?m)^DefaultIM=.*$", text):
    text = re.sub(r"(?m)^DefaultIM=.*$", "DefaultIM=rime", text, count=1)
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(text.lstrip())
PY

    case "$fcitx_mode" in
        unit) fcitx_start unit ;;
        daemon) fcitx_start daemon ;;
    esac

    python3 "$SCRIPT_DIR/rime-lua-compat.py"
fi

# A restart above already read the new classicui config; this covers the path
# where nothing restarted (rime unavailable) so the theme applies immediately.
if fcitx_is_running && busctl --user status org.fcitx.Fcitx5 >/dev/null 2>&1; then
    busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 \
        ReloadAddonConfig s classicui >/dev/null 2>&1 || true
fi
