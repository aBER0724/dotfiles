# nbshell

[nbshell](https://github.com/nerdislb/nbshell) — Nerd Font / TUI 风格的 Quickshell 桌面 Shell(当前主力,替代 Clavis)。

视觉语言偏终端:方形 1px 边框、Nerd Font 符号、紧凑文本表面、块状 meter 而非毛玻璃卡片。

## 目录结构

```
nbshell/
├── install.sh                  # 固定上游 revision 的用户级安装器(绝不 sudo)
├── config/config.json          # 运行时配置(链接到 ~/.config/nbshell/, skip-worktree 管理)
├── scripts/
│   ├── theme-sync.py           # 主题同步生成器: palette.sh / Kitty / pi / lazygit / yazi
│   ├── theme-next-sync         # Alt+T 入口: nbshell next → 轮询 config.json → theme-sync.py
│   ├── theme-hook.sh           # herdr / btop / fcitx5 / Kitty / GTK css / XDG portal / niri 同步
│   └── chromium-controller.mjs # Chromium 启动器+DevTools pipe 控制器(运行中热重载主题)
├── themes/futurism/colors.toml # Futurism 调色板(适配自本地 Omarchy 主题)
├── niri-named-workspaces.patch # niri 命名工作区补丁
└── packages.arch.txt           # 可选 Arch 依赖清单(安装器只检查,不执行 pacman)
```

`scripts/` 下的脚本通过 symlink 挂在 `~/.config/nbshell/`,运行路径不变。

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
| `~/.config/nbshell/theme-next-sync` | 切换主题并同步下游(`Alt+T`) |
| `nbshell wallpaper pick` | 壁纸切换(`Alt+Shift+T`) |
| `nbshell notify center` | 通知中心(`Alt+N`) |
| `nbshell power menu` | 电源菜单(`Alt+Escape`) |
| `nbshell bar toggle` | 仅切换状态栏显示/隐藏(`Alt+B`)，Shell 其他功能保持运行 |

## 主题同步(`Alt+T`)

`Alt+T` 不再直接打开选择器,而是运行 `theme-next-sync`(见 `niri/config.kdl`):

```
nbshell next → 轮询 config.json 直到主题实际变化(最多 1.5s) → theme-sync.py → theme-hook.sh
```

`theme-sync.py` 读取 `config.json` 的当前主题 + `colors.toml`,原子写以下产物:

| 产物 | 生效方式 |
|------|----------|
| `~/.config/nbshell/palette.sh`(NB_* 变量) | nvim / herdr / 脚本共享源 |
| `~/.config/nbshell/kitty.conf` | 通过 Kitty Unix socket 执行 `load-config`,**运行中即时生效** |
| `~/.config/btop/themes/current.theme` | 发送 `SIGUSR2` 重载配置与主题,**运行中即时生效** |
| `~/.pi/agent/themes/nbshell.json`(51+ tokens) | pi 激活 nbshell 主题后,编辑文件即热重载,**运行中即时生效** |
| `~/.config/lazygit/config.yml`(`gui.theme`) | 重启 lazygit 生效 |
| `~/.config/yazi/flavors/<theme>.yazi/` + `theme.toml` | 重启 yazi 生效 |
| `niri/nbshell-colors.kdl`(焦点/边框配色) | config.kdl `include` 引用;niri 监听该文件,自动热重载,**运行中即时生效** |
| `theme-hook.sh` → `herdr/config.toml` managed 块 | `herdr server reload-config`,**运行中即时生效** |
| `~/.config/gtk-3.0/gtk.css` + `gtk-4.0/gtk.css` | 命名色覆盖内建 Adwaita/Default 主题;切换 `gtk-theme` 触发运行中 GTK 应用重载 css |
| `~/.config/gtk-{3,4}.0/settings.ini` | `gtk-application-prefer-dark-theme` 随明暗翻转;新启动的 GTK 应用读取 |
| `~/.config/nbshell/chromium-theme/`(theme extension) | 工具栏/omnibox/新标签页配色;经 controller(`Extensions.loadUnpacked`)**运行中即时生效**,冷启动经 `--load-extension` 兜底 |
| gsettings `org.gnome.desktop.interface` | `color-scheme` 经 xdg-desktop-portal 转发 → Chromium/Electron 的 `prefers-color-scheme`;GTK4 原生跟随 |

对应应用侧集成:

- **nvim**: `~/.config/nvim/colors/nbshell.lua` 动态读 `palette.sh`;`autocmds.lua` 用 500ms timer 轮询 palette mtime,变化即 `colorscheme nbshell`(**运行中即时生效**)。
- **pi**: `~/.pi/agent/settings.json` 的 `theme: "nbshell"`;主题文件热重载机制见 pi 文档 `themes.md`。
- **Kitty**: `~/.config/kitty/kitty.conf` 引入生成的 `~/.config/nbshell/kitty.conf`;切换主题时通过每个 Kitty 进程的 Unix socket 热重载。
- **btop**: 不把完整的 `~/.config/btop/btop.conf` 链接进仓库。该文件包含排序、布局、磁盘/网络设备、GPU 与传感器等运行时及机器相关设置,btop 也会主动改写它。安装器保留这些用户设置,只将 `color_theme` 更新为 `current`;主题同步生成 `~/.config/btop/themes/current.theme`,然后向当前用户的 btop 进程发送 `SIGUSR2` 热重载。`btop.conf` 与自动生成的 `current.theme` 均不提交。
- **lazygit**: 0.64+ 无 `customTheme` 字段,主题内联在 `config.yml` 的 `gui.theme`(hex 需加引号,否则 YAML 注释吞色)。
- **yazi**: flavor 按主题名生成目录;切换主题时写新目录,旧目录保留。
- **Chromium(热重载)**: M121 起 Chromium 不再用 GTK 主题色画自己的 UI,只从 GTK/portal 取明暗,因此工具栏/标签条/omnibox/书签栏/新标签页的配色走 theme extension(`~/.config/nbshell/chromium-theme/manifest.json`,MV3)。两条生效路径: ① 冷启动 —— `chromium-flags.conf` 的 `--load-extension`(hook 自动追加,Omarchy 启动器逐行拼到命令行); ② 运行中 —— `chromium-controller.mjs` 作为浏览器父进程,以 `--remote-debugging-pipe` + `--enable-unsafe-extension-debugging` 启动,hook 经 `$XDG_RUNTIME_DIR/nbshell-chromium.sock` 让它调 CDP `Extensions.loadUnpacked` 重装主题,**无需重启**。该 CDP 域只在 pipe 传输下开放(pipe 私有于父进程,不对本地其他进程暴露;Chrome 136 起 TCP 调试在默认 profile 被禁用),故控制器必须常驻。hook 自动生成 `~/.local/share/applications/chromium.desktop` 覆盖(package 更新时重新生成,手写的覆盖不动,controller/node 消失时自动删除),Exec 指向控制器;终端直接敲 `chromium` 不经过控制器,主题仍由 ① 兜底。浏览器退出时控制器一并退出并清理 socket;日志在 `~/.local/state/nbshell/chromium-controller.log`。网页明暗走 gsettings `color-scheme` → portal(`prefers-color-scheme` 即时跟随);Electron 应用靠 portal 取明暗。chrome://settings/appearance 保持默认(装主题后该页显示 nbshell 主题;若之前手动固定过 Light/Dark,点 Reset to default)。
- **GTK 应用**: GTK3/GTK4 通过 `~/.config/gtk-{3,4}.0/gtk.css` 的命名色(`theme_bg_color`、`accent_color` 等)重着色内建 Adwaita/Default 主题 —— 与 Gradience 同一机制,无需安装主题包,运行中经 `gtk-theme` hop 热重载;明暗同时写入 settings.ini(`gtk-application-prefer-dark-theme`)。手写的 gtk.css(无 nbshell 头注释)不会被覆盖。

日志: `~/.local/state/nbshell/theme-sync.log`。

## 同步的配置(config/config.json)

- 顶栏 bar 模式、中文本地化(`locale: zh_CN`)、24 小时制 `ddd MM-dd HH:mm`、0.94 不透明度、1px 边框
- 数字工作区样式 + 块状 meter / visualizer(契合 niri 命名工作区)
- 配色随主题切换(`Alt+T`),默认基础主题见 `themes/` 与 `~/.local/share/nbshell/themes/`
- 杂项: `bongoActive: false`(关闭桌面 Bongo Cat)、`trayExpanded` 等 UI 状态
- 屏幕保护使用仓库管理的 `config/screensaver.txt` 显示 OMARCHY 字标，并按全屏终端的实际列数动态选择尺寸；字标过宽时自动回退到内置紧凑版本，避免右侧被裁切

**git 管理**: `config.json` 是运行时状态(`theme`、`bongoActive`、`trayExpanded` 随使用变化),已用 `git update-index --skip-worktree nbshell/config/config.json` 标记,不污染 `git status`,也不会拦截 `git pull`。需要提交快照时:

```bash
git update-index --no-skip-worktree nbshell/config/config.json
git add nbshell/config/config.json && git commit -m "nbshell: config snapshot"
git update-index --skip-worktree nbshell/config/config.json
```

## 回滚

换回 Clavis(或 Waybar):

```bash
systemctl --user disable --now nbshell.service
PATH="$HOME/.local/bin:$PATH" QML_IMPORT_PATH="$HOME/.local/lib/qt6/qml" key shell --daemon
```