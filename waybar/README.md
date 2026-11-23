# waybar

niri 桌面上的**顶栏**。nbshell 继续提供启动器 / 通知中心 / OSD / 锁屏 / 主题链,
只把它的 bar 隐藏 —— 两边各做擅长的那半:

- **waybar**:每个模块是独立胶囊(自己的背景、圆角、1px 边框),`icon-size` 是像素级的,
  空工作区能塌缩成零宽。这些 nbshell 的字符网格 bar 做不到。
- **nbshell**:Quickshell 桌面服务与主题管线(`Alt+T` 换主题一次同步 kitty / nvim / herdr /
  pi / lazygit / yazi / fcitx5 / GTK / chromium / niri 焦点环)。

分工与切换方式见根 [README](../README.md) 的 "Niri + nbshell"。

## 目录结构

```
waybar/
├── config.jsonc                # 顶栏布局与模块
├── style.css                   # 样式;调色板 @import 自生成的 ~/.config/nbshell/waybar.css
├── packages.arch.txt           # GTK/gi/wttrbar 依赖清单(安装器只检查,不执行 pacman)
├── install.sh                  # 用户级安装器:检查依赖 + 生成调色板(不 sudo、不停服务)
└── scripts/
    ├── calendar-popup.py       # 时钟下拉日历(GTK3 + layer-shell,主题化)
    ├── power-menu.py           # 电源菜单(GTK3 + layer-shell,主题化)
    └── volume.sh               # 音量(wpctl 解析默认 sink)
```

## 顶栏布局(config.jsonc)

悬浮胶囊:top 层 + 四周 8px 边距,`exclusive: true`(niri layer-shell 独占区,窗口不会盖住)。

| 区域 | 模块 |
|------|------|
| `modules-left` | `niri/workspaces`、`niri/window` |
| `modules-center` | `custom/weather`、`clock` |
| `modules-right` | `tray`、`cpu`、`memory#ram`、`memory#swap`、`disk`、`network`、`custom/pulseaudio`、`backlight`、`battery`、`custom/power` |

## 谁管什么(niri 上的分工)

| 部件 | 谁提供 | 入口 |
|------|--------|------|
| 顶栏 | **waybar** | `niri/config.kdl` 的 `spawn-at-startup "waybar"` |
| 显示/隐藏顶栏 | waybar | `Alt+B` → `pkill -SIGUSR1 -x waybar` |
| 启动器 | nbshell | `Alt+Space` |
| 通知守护 + 通知中心 | nbshell | `Alt+N` |
| OSD(音量/亮度) | nbshell(`osdInPill: false`) | 媒体键 |
| 电源菜单 | `scripts/power-menu.py` | `Alt+Escape`,以及顶栏 `custom/power` |
| 壁纸 / 锁屏 / 护屏 | nbshell | `Alt+Shift+T` 等 |
| 主题 | nbshell `theme-sync.py` | `Alt+T`(waybar 一并换色) |

启动顺序由 [niri/scripts/shell-without-bar.sh](../niri/scripts/shell-without-bar.sh) 负责:
先 `systemctl --user start nbshell.service`,等 IPC 就绪后 `nbshell bar hide`,
然后 `niri/config.kdl` 再拉起 `waybar`。`bar hide` 只 unmaps bar 窗口
([nbshell/bar-visibility.patch](../nbshell/README.md)),其余 shell 功能照常。

## 配色(跟随 `Alt+T`)

waybar 没有自己的主题系统,`style.css` 只能 `@import` GTK 具名颜色:

```css
@import url("../nbshell/waybar.css");
```

- 该文件由 [nbshell/scripts/theme-sync.py](../nbshell/scripts/theme-sync.py) 从当前主题的
  `colors.toml` 生成,每次 `Alt+T` 重写,并 `SIGUSR2` 让 waybar 重新读取样式(运行中即时生效)。
- `scripts/power-menu.py` 和 `scripts/calendar-popup.py` 解析同一份 `@define-color`,
  所以顶栏和两个弹层不会走色。读取顺序:`~/.config/nbshell/waybar.css` →
  `~/.config/omarchy/current/theme/waybar.css` → 脚本内置 DEFAULTS(Futurism 快照)。
- 角色表(Omarchy `waybar.css` 的语义集,换成 nbshell 主题的键):

  | 角色 | 用在 | 来源键 |
  |------|------|--------|
  | `foreground` / `background` | 文字 / 胶囊底色 | `foreground` / `background` |
  | `window` | 窗口标题、聚焦工作区 | `accent` |
  | `date` | 时钟、天气 | `yellow` |
  | `performance` | cpu / 内存 / 磁盘 / 网络 | `blue` |
  | `audio` | 音量 | `magenta` |
  | `misc` | 电池、背光 | `green` |
  | `warning` | 电源键、critical / urgent | `orange` |
  | `caution` | 1px 胶囊边框、空工作区 | `dark_foreground` |
  | `work` / `process` | 备用(Omarchy 对齐) | `blue` / `brown` |

## 启用 / 迁移

`linux-niri` preset 已包含 waybar;单独处理时:

```bash
dotfiles deps waybar        # pacman 装 waybar(其它依赖见 packages.arch.txt)
dotfiles link waybar        # ~/.config/waybar
dotfiles install waybar     # 检查依赖 + 生成 ~/.config/nbshell/waybar.css
```

在一台已有 niri + nbshell 的机器上切过来,只差"隐藏 nbshell 的 bar":

```bash
nbshell bar hide            # 立刻生效;niri/config.kdl 下次开机自动这么做
```

`bar hide` 是**运行时状态**,不写配置:nbshell 重启(手动 `nbshell restart`、崩溃后
systemd 拉起、重装)会把 bar 带回来,再跑一次 `nbshell bar hide` 即可 —— 开机那次由
`shell-without-bar.sh` 负责。

## 回滚到 nbshell 的 bar

```bash
nbshell bar show
```

并在 `niri/config.kdl` 把 `shell-without-bar.sh` 换回 `systemctl --user start nbshell.service`、
删掉 `spawn-at-startup "waybar"`。

## 依赖

- `waybar`(本身由 `dotfiles deps waybar` 安装)
- `python-gobject` / `gtk3` / `gtk-layer-shell`(`calendar-popup.py` 与 `power-menu.py`)
- `wttrbar`(天气模块;基于 wttr.in,无需 API key,`--location Tokyo` 见 `config.jsonc`)
- `wpctl`(PipeWire)供 `volume.sh`
