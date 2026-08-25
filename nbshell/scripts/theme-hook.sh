#!/usr/bin/env bash
# Runs after nbshell exports ~/.config/nbshell/palette.sh.
# Synchronizes applications whose palettes are not managed directly by QML.
set -u

palette="${XDG_CONFIG_HOME:-$HOME/.config}/nbshell/palette.sh"
[ -r "$palette" ] || exit 0
# shellcheck disable=SC1090
. "$palette"

# Herdr supports a fixed set of named base themes. Pick the nearest built-in
# family, then override its UI tokens with the exact nbshell palette.
case "${NB_THEME:-}" in
  catppuccin-latte) herdr_base="catppuccin-latte" ;;
  catppuccin*) herdr_base="catppuccin" ;;
  tokyo-night) herdr_base="tokyo-night" ;;
  gruvbox) herdr_base="gruvbox" ;;
  kanagawa) herdr_base="kanagawa" ;;
  rose-pine) herdr_base="rose-pine" ;;
  nord) herdr_base="nord" ;;
  *solarized*|osaka-jade) herdr_base="solarized" ;;
  *) [ "${NB_MODE:-dark}" = light ] && herdr_base="catppuccin-latte" || herdr_base="terminal" ;;
esac

herdr_config="${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml"
if [ -f "$herdr_config" ]; then
  python3 - "$herdr_config" "$herdr_base" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
base = sys.argv[2]
text = path.read_text()
colors = {}
for line in Path.home().joinpath('.config/nbshell/palette.sh').read_text().splitlines():
    m = re.match(r"NB_([A-Z_]+)='([^']*)'$", line)
    if m:
        colors[m.group(1)] = m.group(2)

block = f'''# BEGIN nbshell managed theme
[theme]
name = "{base}"
auto_switch = false

[theme.custom]
sidebar_bg = "{colors.get('BG_DARK', colors['BG'])}"
active_row_bg = "{colors.get('BG_LIGHT', colors['BG'])}"
selection_bg = "{colors.get('SELECTION', colors.get('BG_LIGHT', colors['BG']))}"
panel_bg = "{colors['BG']}"
accent = "{colors['ACCENT']}"
red = "{colors['RED']}"
green = "{colors['GREEN']}"
# END nbshell managed theme'''

managed = re.compile(r'# BEGIN nbshell managed theme.*?# END nbshell managed theme', re.S)
if managed.search(text):
    text = managed.sub(block, text)
else:
    # Replace the existing top-level [theme] section, including theme.custom if
    # present, while preserving all unrelated Herdr configuration.
    section = re.compile(r'(?ms)^\[theme\]\n.*?(?=^\[(?!theme(?:\.|\]))|\Z)')
    if section.search(text):
        text = section.sub(block + '\n\n', text, count=1)
    else:
        text = block + '\n\n' + text
path.write_text(text)
PY
  command -v herdr >/dev/null 2>&1 && herdr server reload-config >/dev/null 2>&1 || true
fi

# Existing Neovim instances watch palette.sh. Newly launched instances load the
# same generated colorscheme from ~/.config/nvim/colors/nbshell.lua.
exit 0
