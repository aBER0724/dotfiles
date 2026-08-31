#!/usr/bin/env bash
# Install nbshell entirely under the current user's home directory.
# This script never invokes sudo or a system package manager.
set -euo pipefail

PREFIX="${NBSHELL_PREFIX:-$HOME/.local}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/nbshell-source"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

NBSHELL_REPO="https://github.com/nerdislb/nbshell"
NBSHELL_REV="94fcf5804b5e6d66f80792e036f2d76aadd2e083"
RUNTIME_DIR="$PREFIX/share/quickshell/nbshell"
BIN_DIR="$PREFIX/bin"
UNIT_DIR="$CONFIG_HOME/systemd/user"
CONFIG_DIR="$CONFIG_HOME/nbshell"
CONFIG_FILE="$CONFIG_DIR/config.json"
SCREENSAVER_FILE="$CONFIG_DIR/screensaver.txt"
THEME_DIR="$DATA_HOME/nbshell/themes"
WALLPAPER_DIR="$DATA_HOME/nbshell/wallpapers"
FCITX_CONFIG_DIR="$CONFIG_HOME/fcitx5"

required_commands="git qs niri python3 bash flock fc-list"
missing=""
for command_name in $required_commands; do
    command -v "$command_name" >/dev/null 2>&1 || missing="$missing $command_name"
done
if [[ -n "$missing" ]]; then
    cat >&2 <<EOF
nbshell installer: missing commands:$missing
Install the required dependencies manually, then rerun this installer.

No privileged command was executed.
EOF
    exit 2
fi

optional_packages=()
while IFS= read -r package_name; do
    [[ -n "$package_name" && "$package_name" != \#* ]] || continue
    if ! command -v pacman >/dev/null 2>&1 || ! pacman -Q "$package_name" >/dev/null 2>&1; then
        optional_packages+=("$package_name")
    fi
done < "$SCRIPT_DIR/packages.arch.txt"

if ((${#optional_packages[@]})); then
    printf '\nnbshell optional Arch packages are missing: %s\n' "${optional_packages[*]}" >&2
    printf 'Install manually if those features are wanted:\n  sudo pacman -S --needed' >&2
    printf ' %q' "${optional_packages[@]}" >&2
    printf '\n\n' >&2
fi

if command -v tuned-adm >/dev/null 2>&1; then
    if ! systemctl is-enabled tuned.service >/dev/null 2>&1 || ! systemctl is-active tuned.service >/dev/null 2>&1; then
        cat >&2 <<'EOF'

tuned is installed but its system service is not enabled and active.
Enable it manually if nbshell power profiles are wanted:
  sudo systemctl enable --now tuned.service
EOF
    fi
fi

clone_at() {
    local repo=$1 revision=$2 destination=$3
    if [[ ! -d "$destination/.git" ]]; then
        rm -rf "$destination"
        git clone --filter=blob:none "$repo" "$destination"
    fi
    git -C "$destination" fetch --depth 1 origin "$revision"
    git -C "$destination" checkout --detach "$revision"
    git -C "$destination" reset --hard "$revision"
    git -C "$destination" clean -fdx
}

mkdir -p "$CACHE" "$BIN_DIR" "$UNIT_DIR" "$THEME_DIR" "$WALLPAPER_DIR"
clone_at "$NBSHELL_REPO" "$NBSHELL_REV" "$CACHE/source"
for patch_file in niri-named-workspaces.patch bar-visibility.patch screensaver-fit.patch screensaver-preview.patch kitty-screensaver-fullscreen.patch remove-bongo-cat.patch tray-polish.patch popout-gap.patch tailscale-official-icon.patch rime-tray-icon.patch; do
    git -C "$CACHE/source" apply --check "$SCRIPT_DIR/$patch_file"
    git -C "$CACHE/source" apply "$SCRIPT_DIR/$patch_file"
done

printf '\n== Validate pinned nbshell source ==\n'
bash -n "$CACHE/source/bin/nbshell" "$CACHE/source/bin/nbshell-install-recover"
while IFS= read -r -d '' script; do
    bash -n "$script"
done < <(find "$CACHE/source/shell/scripts" -type f -name '*.sh' -print0)
python3 -m compileall -q "$CACHE/source/shell/scripts"

printf '\n== Install user-local runtime ==\n'
staged=$(mktemp -d "$PREFIX/share/quickshell/.nbshell-stage.XXXXXX")
cleanup() {
    if [[ -n "${staged:-}" && -d "$staged" ]]; then
        rm -rf "$staged"
    fi
    return 0
}
trap cleanup EXIT
cp -a "$CACHE/source/shell/." "$staged/"
install -m 0644 "$CACHE/source/VERSION" "$staged/VERSION"
rm -rf "$RUNTIME_DIR"
mv "$staged" "$RUNTIME_DIR"
staged=""

install -m 0755 "$CACHE/source/bin/nbshell" "$BIN_DIR/nbshell"
install -m 0755 "$CACHE/source/bin/nbshell-install-recover" "$BIN_DIR/nbshell-install-recover"

cat > "$UNIT_DIR/nbshell.service" <<EOF
[Unit]
Description=nbshell Nerd/TUI desktop shell
Documentation=https://github.com/nerdislb/nbshell
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
Environment="PATH=%h/.local/bin:%h/.cargo/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/sbin:/usr/local/bin:/usr/bin"
Environment="MALLOC_CONF=thp:never,narenas:4,dirty_decay_ms:3000"
ExecStart=$BIN_DIR/nbshell start
ExecReload=$BIN_DIR/nbshell restart
Restart=on-failure
RestartSec=2
TimeoutStopSec=5

[Install]
WantedBy=graphical-session.target
EOF
systemctl --user daemon-reload

printf '\n== Install themes and wallpapers ==\n'
rm -rf "$THEME_DIR"
mkdir -p "$THEME_DIR"
cp -a "$CACHE/source/themes/." "$THEME_DIR/"
install -d "$THEME_DIR/futurism"
install -m 0644 "$SCRIPT_DIR/themes/futurism/colors.toml" "$THEME_DIR/futurism/colors.toml"

mkdir -p "$CONFIG_DIR"
if [[ -L "$CONFIG_DIR" ]]; then
    rm -f "$CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
fi
ln -sfnT "$SCRIPT_DIR/config/config.json" "$CONFIG_FILE"
ln -sfnT "$SCRIPT_DIR/config/screensaver.txt" "$SCREENSAVER_FILE"
rm -rf "$CONFIG_DIR/themes"
ln -sfnT "$THEME_DIR" "$CONFIG_DIR/themes"
rm -rf "$WALLPAPER_DIR"
mkdir -p "$WALLPAPER_DIR"
cp -a "$CACHE/source/wallpapers/." "$WALLPAPER_DIR/"
omarchy_wallpapers="$CONFIG_HOME/omarchy/themes/futurism/backgrounds"
if [[ -d "$omarchy_wallpapers" ]]; then
    ln -sfn "$omarchy_wallpapers" "$WALLPAPER_DIR/futurism"
fi

printf '\n== Configure Kitty terminal ==\n'
mkdir -p "$CONFIG_HOME/kitty" "$CONFIG_HOME/environment.d"
ln -sfnT "$SCRIPT_DIR/../kitty/kitty.conf" "$CONFIG_HOME/kitty/kitty.conf"
ln -sfnT "$SCRIPT_DIR/../kitty/platform-linux.conf" "$CONFIG_HOME/kitty/platform-linux.conf"
ln -sfnT "$SCRIPT_DIR/../kitty/platform-macos.conf" "$CONFIG_HOME/kitty/platform-macos.conf"
ln -sfnT "$SCRIPT_DIR/../kitty/tab_bar.py" "$CONFIG_HOME/kitty/tab_bar.py"
ln -sfnT "$SCRIPT_DIR/../kitty/watcher.py" "$CONFIG_HOME/kitty/watcher.py"
cat > "$CONFIG_HOME/environment.d/50-terminal.conf" <<'EOF'
TERMINAL=kitty
EOF
mkdir -p "$DATA_HOME/applications"
cat > "$DATA_HOME/applications/kitty-default.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Kitty Terminal
Comment=Open Kitty terminal
Exec=kitty
Icon=kitty
Terminal=false
Categories=System;TerminalEmulator;
MimeType=x-scheme-handler/terminal;
EOF
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DATA_HOME/applications" >/dev/null 2>&1 || true
fi
if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default kitty-default.desktop x-scheme-handler/terminal || true
fi

printf '\n== Install Fcitx5/Rime candidate UI ==\n'
mkdir -p "$FCITX_CONFIG_DIR/conf"
ln -sfnT "$SCRIPT_DIR/../fcitx5/conf/classicui.conf" "$FCITX_CONFIG_DIR/conf/classicui.conf"
ln -sfnT "$SCRIPT_DIR/../fcitx5/conf/kimpanel.conf" "$FCITX_CONFIG_DIR/conf/kimpanel.conf"
python3 - "$FCITX_CONFIG_DIR/config" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text() if path.exists() else "[Behavior]\n"
text = re.sub(r'(?ms)^\[Behavior/DisabledAddons\]\n.*?(?=^\[|\Z)', '', text).rstrip()
path.write_text(text + "\n\n[Behavior/DisabledAddons]\n0=kimpanel\n")
PY

# Install the user's Rime configuration when fcitx5-rime is available. Keep a
# clean source checkout separate from Rime's generated build/ and user data.
if [ -f /usr/share/fcitx5/inputmethod/rime.conf ]; then
    rime_dir="$DATA_HOME/fcitx5/rime"
    rime_source="$DATA_HOME/nbshell/rime-config"
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
fi
python3 "$SCRIPT_DIR/../fcitx5/rime-lua-compat.py"

# Keep btop's user preferences, but point its palette at the generated theme.
mkdir -p "$CONFIG_HOME/btop/themes"
python3 - "$CONFIG_HOME/btop/btop.conf" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text() if path.exists() else ""
setting = 'color_theme = "current"'
if re.search(r'(?m)^color_theme\s*=.*$', text):
    text = re.sub(r'(?m)^color_theme\s*=.*$', setting, text, count=1)
elif text:
    text = setting + "\n" + text
else:
    text = setting + "\n"
path.write_text(text)
PY
install -m 0755 "$SCRIPT_DIR/scripts/theme-sync.py" "$CONFIG_DIR/theme-sync.py"
install -m 0755 "$SCRIPT_DIR/scripts/theme-hook.sh" "$CONFIG_DIR/theme-hook.sh"
install -m 0755 "$SCRIPT_DIR/scripts/chromium-controller.mjs" "$CONFIG_DIR/chromium-controller.mjs"
ln -sfnT "$SCRIPT_DIR/scripts/theme-next-sync" "$CONFIG_DIR/theme-next-sync"
"$CONFIG_DIR/theme-sync.py"
mkdir -p "$CONFIG_HOME/quickshell"
ln -sfn "$RUNTIME_DIR" "$CONFIG_HOME/quickshell/nbshell"

if ! fc-list 2>/dev/null | grep -ci 'JetBrainsMono.*Nerd Font' >/dev/null; then
    echo "nbshell installer: JetBrainsMono Nerd Font was not found." >&2
    echo "Install a Nerd Font manually before starting nbshell." >&2
    exit 2
fi

cat <<EOF

nbshell installed without elevated privileges.
  command:    $BIN_DIR/nbshell
  runtime:    $RUNTIME_DIR
  config:     $CONFIG_FILE -> $SCRIPT_DIR/config/config.json
  themes:     $THEME_DIR
  service:    $UNIT_DIR/nbshell.service

Start now with:
  systemctl --user enable --now nbshell.service

Clavis remains installed as a manual rollback.
EOF
