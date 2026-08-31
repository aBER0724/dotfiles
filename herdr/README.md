# herdr

[herdr](https://herdr.dev) 终端工作区管理器(面向 AI coding agent),跨设备同步。
此为 v0.8.2 时代的配置;插件通过 `plugins.txt` 清单重装,不提交安装产物。

## 来源

- [herdr](https://herdr.dev) — 本体(official formula `brew install herdr`)
- [herdr-scratch](https://github.com/macintacos/herdr-scratch) — macOS 使用 cask 二进制，Linux 由 herdr 从源码构建
- 9 个 GitHub 插件，见「插件清单」

## 目录结构

```
herdr/
├── config.toml          # 主题 / 键位 / UI(同步)
├── plugins.txt          # 插件清单:owner/repo + 固定 ref(同步)
├── gen-plugins.sh       # 设备上改动插件后重新生成 plugins.txt
└── install-plugins.sh   # 新设备按清单重装全部插件
```

## 插件清单(来自 plugins.txt)

| 插件 ID | 来源仓库 | 说明 |
|---------|---------|------|
| `dave.token-dashboard` | [Davidcreador/herdr-token-dashboard](https://github.com/Davidcreador/herdr-token-dashboard) | token 用量面板(Go 构建) |
| `herdr-lazygit` | [crokily/herdr-lazygit](https://github.com/crokily/herdr-lazygit) | lazygit 集成 |
| `herdr-navigator` | [thanhdat77/herdr-navigator](https://github.com/thanhdat77/herdr-navigator) | 跳转面板 |
| `herdr-plugin-renamer` | [wenhanweime/herdr-plugin-renamer](https://github.com/wenhanweime/herdr-plugin-renamer) | 插件重命名 |
| `herdr-workspacer` | [mcuste/herdr-workspacer](https://github.com/mcuste/herdr-workspacer) | workspace 切换面板 |
| `mirror` | [nikok6/herdr-mirror](https://github.com/nikok6/herdr-mirror) | 远程镜像/同步面板 |
| `ray.file-explorer` | [speardragon/herdr-yazi](https://github.com/speardragon/herdr-yazi) | yazi 文件浏览器 |
| `ray.plugin-manager` | [speardragon/herdr-plugin-manager](https://github.com/speardragon/herdr-plugin-manager) | 插件管理器 UI |
| `user.scratch` | [macintacos/herdr-scratch](https://github.com/macintacos/herdr-scratch) | 弹出式 scratch shell（Linux 源码构建，macOS cask） |

> 已固定版本的 GitHub 插件使用 `plugins.txt` 中的 ref；scratch 跟随当前上游版本，以便 Linux 获得受支持的构建。

## Keybindings(config.toml)

prefix 按 herdr 默认(通常 `Ctrl+b` 系)。以下为绑定的插件命令:

| 按键 | 命令 | 说明 |
|------|------|------|
| `prefix+g` | `herdr-lazygit.open` | lazygit:分屏打开 |
| `prefix+shift+g` | `herdr-lazygit.open-tab` | lazygit:新 tab 打开 |
| `prefix+'` | `user.scratch.toggle` | scratch shell |
| `prefix+y` | `ray.file-explorer.open` | yazi:分屏打开 |
| `prefix+Y` | `ray.file-explorer.open-tab` | yazi:新 tab 打开 |
| `prefix+shift+m` | `mirror.start` | 启动镜像 daemon |
| `prefix+shift+s` | `mirror.pause` | 冻结镜像同步 |
| `prefix+shift+b` | `mirror.restore` | 恢复本地关闭的镜像 |
| `prefix+alt+d` | `mirror.teardown` | ⚠️ 销毁全部镜像+清状态 |
| `prefix+alt+n` | `mirror.remote-new-workspace` | 远端新建 workspace |
| `prefix+alt+c` | `mirror.remote-new-tab` | 远端新建 tab |
| `prefix+alt+v` | `mirror.remote-split-right` | 远端右分屏 |
| `prefix+alt+minus` | `mirror.remote-split-down` | 远端下分屏 |
| `prefix+p` | `ray.plugin-manager.open` | 打开插件管理器 |
| `prefix+t` | `herdr-navigator.open` | 跳转面板 |
| `prefix+alt+s` | `herdr-navigator.open-side` | 跳转面板:常驻侧边面板 |
| `prefix+alt+j` | `herdr-navigator.jump-back` | 跳转面板:跳回上一位置 |
| `prefix+alt+o` | `mirror.once` | 一次性同步(不启动 daemon) |
| `prefix+shift+i` | `mirror.status` | 查看 daemon/主机/镜像状态 |
| `prefix+$` | `dave.token-dashboard.open-dashboard` | 打开 token 用量面板 |

> herdr 不解析插件 manifest 里的 `[[keys.command]]`(manifest 字段只有 id/name/version/description/
> platforms/build/startup/actions/events/panes/link_handlers),插件自带的键位声明是死代码,必须在本表显式绑定。

### 原生 pane/tab 移动(`[keys]`段,herdr 默认不绑)

| 按键 | 动作 | 说明 |
|------|------|------|
| `prefix+shift+h` | `swap_pane_left` | 当前 pane 与左侧 pane 交换位置 |
| `prefix+shift+j` | `swap_pane_down` | 与下方 pane 交换 |
| `prefix+shift+k` | `swap_pane_up` | 与上方 pane 交换 |
| `prefix+shift+l` | `swap_pane_right` | 与右侧 pane 交换 |
| `alt+shift+left` | `move_tab_previous` | 当前 tab 向左移动(直接键,无需 prefix) |
| `alt+shift+right` | `move_tab_next` | 当前 tab 向右移动 |

> shift+h/j/k/l 与原生 focus h/j/k/l 同方向,`swap` 即 `focus 键位 + shift`。
> review:branch 常被 `review` 覆盖(分支领先时 review 即显示分支 diff)。

## 为什么 plugins.json 不同步

herdr 的 `plugins.json` 记录绝对安装路径(`/Users/aber/.config/herdr/plugins/...`),
机器相关。改为同步 `plugins.txt`(owner/repo + ref),新设备一条命令重装。

## 主题同步(nbshell managed 块)

`config.toml` 内含 `# BEGIN/END nbshell managed theme` 块(见 [nbshell theme-sync](../nbshell/README.md)):

- `[theme] name + auto_switch = false` 固定基础主题(catppuccin / terminal / tokyo-night / dracula / nord / gruvbox / one-dark / solarized / kanagawa / rose-pine / vesper);无内置映射时回退到 `terminal`
- `[theme.custom]` 用真实主题色覆盖(BG / accent / red / green / selection 等)
- 每次 `Alt+T` 由 theme-hook.sh 重写该块,再 `herdr server reload-config`,运行中即时生效

## 鼠标模式泄漏(SGR)防护

症状:退出 herdr / SSH 断线后,回到 shell 输入行里出现 `[<35;x;yM` 这类裸 SGR 序列,
滚轮、鼠标移动被当成键盘输入。

原因:TUI 崩溃或被强杀时没发送 `?1003l` / `?1006l` 关闭鼠标上报;鼠标模式是**终端模拟器
(如 Kaku)的属性**,远程进程死在 SSH 里、本地终端却一直保持 1003h/1006h,回到本地 shell 即泄漏。

herdr 侧(已由上游修复,需 ≥0.8.0):

- **0.8.0** 起,SIGHUP / SIGTERM 时恢复终端状态(#2041)——SSH 断线杀进程不再泄漏
- **0.7.2** 起,SGR 鼠标上报不再泄漏进 pane(#939)
- **0.8.2** 起,detach 恢复宿主键盘上报(#2393)、默认解码鼠标上报(#2309)

```bash
herdr --version          # 本机;确认 ≥ 0.8.0
ssh firebat 'herdr --version'   # 远程;低版本是 SSH 断线泄漏的头号原因,升级: brew upgrade herdr
```

shell 侧兜底(已内置在 zsh/zshrc):每次绘制提示符前自动发送
`ESC[?1000l ?1002l ?1003l ?1006l`,无论哪个 TUI 残留都能清掉;应急可手动 `fixmouse`。
若不用 herdr 的鼠标交互,也可在 config.toml 设 `[ui] mouse_capture = false` 彻底关闭宿主鼠标捕获。
## 新设备安装

```bash
# Recommended on a fresh macOS or Arch device:
bash ~/dotfiles/bin/dotfiles setup auto

# To repair only herdr and its plugins:
brew install herdr

# macOS only; Linux casks are unsupported:
brew install --cask macintacos/tap/herdr-scratch

# Linux builds scratch through herdr; this is also safe to rerun on macOS:
bash ~/dotfiles/herdr/install-plugins.sh
```

> 有 Go 构建步骤的插件（token-dashboard、Linux 上的 scratch）需要 Go；navigator 和 renamer 需要 Rust/Cargo；file-explorer 需要 Yazi。
> `setup` / `deps herdr` 会安装这些依赖。若直接运行本脚本且依赖缺失，它会在尝试插件前停止并给出恢复命令；其他安装错误仍会显示每个插件的实际日志。