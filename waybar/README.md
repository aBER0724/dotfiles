# waybar

**遗留配置** — Waybar 已被 [nbshell](../nbshell/)(当前主力)取代,仅在需要第二条手动回滚路径时使用。

niri 版顶栏:模块已从 Hyprland 迁移到 `niri/*`。

## 目录结构

```
waybar/
├── config.jsonc                # 顶栏布局与模块配置(链接到 ~/.config/waybar/)
├── style.css                   # 样式 —— 颜色由 omarchy 主题提供,切主题自动跟随
└── scripts/
    ├── calendar-popup.py       # 时钟的下拉日历(主题化)
    ├── power-menu.py           # 电源下拉菜单(主题化)
    └── volume.sh               # 音量脚本(wpctl 解析默认 sink)
```

## 顶栏布局(config.jsonc)

悬浮胶囊:top 层 + 四周 8px 边距,`exclusive: true`(niri layer-shell 独占区,窗口不会盖住)。

| 区域 | 模块 |
|------|------|
| `modules-left` | `niri/workspaces`、`niri/window` |
| `modules-center` | `custom/weather`、`clock` |
| `modules-right` | `tray`、`cpu`、`memory#ram`、`memory#swap`、`network`、`custom/pulseaudio`、`backlight`、`battery`、`custom/power` |

## 样式(style.css)

- 顶部 `@import url("../omarchy/current/theme/waybar.css")` 引入主题调色板(`@foreground` / `@background` / `@warning` 等变量),切换主题(`Alt+T`)后颜色自动跟随
- 其余为重置、关键帧(如 critical 闪烁)与模块专属样式

## 手动启用(回滚场景)

```bash
# 1. 装 waybar(发行版包管理器)
# 2. 链接配置
ln -sf ~/dotfiles/waybar ~/.config/waybar
# 3. 在 niri config.kdl 里改成 spawn waybar(并停掉 nbshell.service)
systemctl --user disable --now nbshell.service
```

## 依赖

- `pulseaudio` / `wpctl`(PipeWire)供音量脚本
- `python3`(calendar-popup.py / power-menu.py)
- 天气模块用 `wttrbar`(基于 wttr.in,无需 API key,`--location Tokyo` 见 config.jsonc 的 `custom/weather` 段),需单独安装该二进制