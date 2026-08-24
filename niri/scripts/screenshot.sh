#!/bin/bash
# niri 截图助手 — 依赖: grim + slurp(可选用 wl-clipboard 复制到剪贴板)
# 用法: screenshot.sh region | full
mode="${1:-region}"
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

case "$mode" in
  region)
    # -b 遮罩背景 / -c 选区边框 (Catppuccin Mocha 色)
    grim -g "$(slurp -b 1B1B26CC -c CBA6F7FF)" "$file" || exit 1
    ;;
  full)
    grim "$file" || exit 1
    ;;
  *)
    echo "usage: screenshot.sh {region|full}" >&2
    exit 2
    ;;
esac

# 装了 wl-clipboard 就顺手复制到剪贴板
if command -v wl-copy >/dev/null 2>&1; then
  wl-copy -t image/png < "$file"
fi

notify-send -a screenshot "截图已保存" "$file" -i "$file"
