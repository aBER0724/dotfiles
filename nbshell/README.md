# nbshell

[nbshell](https://github.com/nerdislb/nbshell) — Nerd Font / TUI 风格的 Quickshell 桌面 Shell(当前主力,替代 Clavis)。

视觉语言偏终端:方形 1px 边框、Nerd Font 符号、紧凑文本表面、块状 meter 而非毛玻璃卡片。

## 目录结构

```
nbshell/
├── install.sh                  # 固定上游 revision 的用户级安装器(绝不 sudo)
├── config/config.json          # 同步的运行时配置(链接到 ~/.config/nbshell/)
├── themes/futurism/colors.toml # Futurism 调色板(适配自本地 Omarchy 主题)
├── niri-named-workspaces.patch # niri 命名工作区补丁
└── packages.arch.txt           # 可选 Arch 依赖清单(安装器只检查,不执行 pacman)
```

## 安装

`nbshell/install.sh` 把运行时、CLI、主题、用户级 service 全部装到 `~/.local` / `~/.config` 之下,固定上游 commit,校验脚本后安装。**从不调用 `sudo` 或包管理器**。

```bash
bash ~/dotfiles/nbshell/install.sh   # 或 dotfiles install nbshell
```

安装器会检查 `packages.arch.txt`(tuned / khal / vdirsyncer / gpu-screen-recorder),缺失时只打印手动的 `sudo pacman -S --needed ...` 命令,不自动执行。`tuned` 还需一次性手动执行:

```bash
sudo systemctl enable --now tuned.service
```

## 启用

```bash
systemctl --user enable --now nbshell.service   # 启动并开机自启
nbshell stop                                     # 停止
```

## 常用命令

| 命令 | 说明 |
|------|------|
| `nbshell launcher` | 应用启动器(`Alt+Space`) |
| `nbshell dashboard` | 仪表盘(`Alt+Ctrl+T`) |
| `nbshell picker` | 主题切换(`Alt+T`) |
| `nbshell wallpaper pick` | 壁纸切换(`Alt+Shift+T`) |
| `nbshell notify center` | 通知中心(`Alt+N`) |

## 同步的配置(config/config.json)

- 主题 `futurism`、顶栏 bar 模式、0.94 不透明度、1px 边框
- 中文本地化(`locale: zh_CN`)、24 小时制 `ddd MM-dd HH:mm`
- 数字工作区样式 + 块状 meter / visualizer(契合 niri 命名工作区)
- 配色改 `themes/futurism/colors.toml`(accent `#00BFFF` 系,详见文件),字体默认 `JetBrainsMono Nerd Font`

## 回滚

换回 Clavis(或 Waybar):

```bash
systemctl --user disable --now nbshell.service
PATH="$HOME/.local/bin:$PATH" QML_IMPORT_PATH="$HOME/.local/lib/qt6/qml" key shell --daemon
```