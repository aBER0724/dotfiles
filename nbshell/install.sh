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
THEME_DIR="$DATA_HOME/nbshell/themes"
WALLPAPER_DIR="$DATA_HOME/nbshell/wallpapers"

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
git -C "$CACHE/source" apply --check "$SCRIPT_DIR/niri-named-workspaces.patch"
git -C "$CACHE/source" apply "$SCRIPT_DIR/niri-named-workspaces.patch"

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
rm -rf "$CONFIG_DIR/themes"
ln -sfnT "$THEME_DIR" "$CONFIG_DIR/themes"
rm -rf "$WALLPAPER_DIR"
mkdir -p "$WALLPAPER_DIR"
cp -a "$CACHE/source/wallpapers/." "$WALLPAPER_DIR/"
omarchy_wallpapers="$CONFIG_HOME/omarchy/themes/futurism/backgrounds"
if [[ -d "$omarchy_wallpapers" ]]; then
    ln -sfn "$omarchy_wallpapers" "$WALLPAPER_DIR/futurism"
fi

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
