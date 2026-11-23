#!/usr/bin/env bash
# waybar 顶栏的用户级安装器 —— 与仓库其它 install.sh 一样:不调用 sudo、
# 不装包、不停服务,缺的东西和下一步只打印出来。
set -u

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
palette="$config_home/nbshell/waybar.css"

echo "== waybar =="

# ── 依赖检查(只报告)────────────────────────────────────────
if command -v pacman >/dev/null 2>&1; then
  missing=()
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    pacman -Q "$line" >/dev/null 2>&1 || missing+=("$line")
  done < "$here/packages.arch.txt"
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "missing Arch packages (run manually):"
    echo "  sudo pacman -S --needed ${missing[*]}"
  else
    echo "deps    ok"
  fi
fi

# ── 调色板 ──────────────────────────────────────────────────
# waybar 没有自己的主题系统:style.css 只 import GTK 具名颜色。nbshell 的
# theme-sync.py 在 niri 上生成这个文件(Alt+T 会连 bar 一起换色);Omarchy 机器
# 上则用它自己写的同结构文件播种一次。
if [ -s "$palette" ]; then
  echo "theme   ${palette/#$HOME/\~} already present"
else
  sync_py="$config_home/nbshell/theme-sync.py"
  if [ -f "$sync_py" ]; then
    if python3 "$sync_py"; then
      echo "theme   waybar palette generated from the nbshell theme"
    else
      echo "waybar: theme-sync.py failed; see ~/.local/state/nbshell/theme-sync.log" >&2
    fi
  elif [ -r "$config_home/omarchy/current/theme/waybar.css" ]; then
    mkdir -p "$config_home/nbshell"
    cp "$config_home/omarchy/current/theme/waybar.css" "$palette"
    echo "theme   waybar palette seeded from the Omarchy theme"
  else
    echo "waybar: no palette source yet — style.css needs $palette" >&2
    echo "        run 'dotfiles install nbshell' (niri) first" >&2
  fi
fi

# ── 下一步是手动的 ──────────────────────────────────────────
cat <<'NEXT'

Next (manual, once):
  dotfiles link waybar               # ~/.config/waybar
  nbshell bar hide                   # 只隐藏 nbshell 的 bar,其余功能继续跑
  systemctl --user start nbshell     # 启动器/通知/OSD/锁屏/主题链的来源
  waybar                             # 顶栏;niri 的 spawn-at-startup 会接管

niri 上这两步已写进 niri/config.kdl + niri/scripts/shell-without-bar.sh。
NEXT
