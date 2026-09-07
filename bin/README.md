# bin

`dotfiles` CLI — 一条命令管理 `~` 与 `~/dotfiles` 之间的所有符号链接。

## 目录结构

```
bin/
└── dotfiles    # bash 3.2 兼容的单文件脚本,零依赖
```

## 安装

```bash
git clone https://github.com/aBER0724/dotfiles.git ~/dotfiles
bash ~/dotfiles/bin/dotfiles setup auto
```

## 用法

```
dotfiles {list|status|link|install|deps|setup} [name...]
```

| 命令 | 说明 |
|------|------|
| `list` | 列出所有受管条目(name → 源 → 目标) |
| `status [name...]` | 显示链接状态:`ok` / `STALE` / `CONFLICT` / `missing`(默认全部) |
| `link [name...]` | 创建缺失链接;目标已有真实文件时备份到 `~/.dotfiles-backup-<时间戳>` 再替换 |
| `install [name...]` | `link` + 自动安装该配置的软件本体与分组运行时依赖 |
| `deps [name...]` | 只装软件/依赖而不碰链接；默认处理全部配置 |
| `setup [auto\|macos\|linux\|server] [auto\|server\|omarchy]` | 检测或指定系统；`setup server` 是支持 root 的无桌面快捷方式 |

## 系统一键安装

```bash
dotfiles setup auto           # macOS；Arch→omarchy；Ubuntu/Debian→server
dotfiles setup macos          # macOS 主力配置
dotfiles setup linux omarchy  # Arch/Omarchy + Niri/nbshell/Kitty
dotfiles setup server         # 无桌面的 Ubuntu/Debian；允许 root
```

- 共享主力配置：dotfiles CLI、Zsh、Neovim、Fastfetch、pi、herdr。
- macOS 额外安装并链接 AeroSpace 和 Kitty；缺少 Homebrew 时从官方固定 URL 自动安装。
- `linux omarchy`：面向 Arch/Omarchy 桌面，安装并链接 Niri、nbshell 和 Kitty；通过 `pacman` 安装原生依赖和 `nbshell/packages.arch.txt`。
- `server`（或 `linux server`）：面向偏生产环境的无桌面 Ubuntu/Debian，允许直接以 root 运行；只安装共享终端栈，通过 `apt-get` 和官方 Linux release 安装依赖、Herdr、Yazi、Fastfetch，不使用 Homebrew，也不链接或运行 Niri、nbshell、Kitty、输入法和桌面服务。
- `linux omarchy` 在原生包安装后按需引导 Linuxbrew，用于跨发行版工具；server profile 明确跳过 Linuxbrew。
- Linux 由 herdr 插件安装器从源码构建 scratch，不安装 `herdr-scratch` cask，也不安装 `python-xattr`。
- `setup arch` 暂时保留为 `setup linux omarchy` 的兼容别名，并打印弃用提示。
- Waybar、Clavis、Kaku 属于备用/回滚配置，不在系统预设中。
- 配置冲突仍使用时间戳目录备份，重复运行会跳过正确链接和已安装命令。
- setup 不启动 AeroSpace、不修改登录 Shell、不写入 pi API key，也不自动启用 systemd 服务。
Arch 完成后按需手动执行：

```bash
systemctl --user enable --now nbshell.service
sudo systemctl enable --now tuned.service
```

### 分组

`dotfiles link pi`、`dotfiles install wm` 等会展开为组内全部条目:

| 分组 | 成员 |
|------|------|
| `pi` | pi-settings, pi-models, pi-extensions |
| `zsh` | zshrc, zshenv, zprofile, shinit, p10k |
| `kitty` | kitty-main, kitty-linux, kitty-macos |
| `herdr` | herdr |
| `wm` | niri, nbshell |

`install` / `deps` 的安装策略:

- `setup linux omarchy` 会先使用 pacman 安装原生依赖；细粒度 `install` / `deps` 在 Homebrew 可用时优先使用 Homebrew，否则在 Arch 上回退到 pacman
- 只安装所选配置的软件；不传名称时处理全部配置
- 已存在的命令会跳过，保持幂等
- 当前自动覆盖 AeroSpace、Zsh、Neovim、Niri、Waybar、Quickshell/Fcitx5/Kitty、Fastfetch、pi、herdr 与 herdr-scratch
- Kaku 等没有稳定包管理器映射的软件会提示手动安装
- herdr / zsh / clavis / nbshell 仍按选择运行各自的插件或用户级安装脚本

## 环境变量

| 变量 | 默认 | 说明 |
|------|------|------|
| `DOTFILES_DIR` | `~/dotfiles` | 仓库路径 |
| `DOTFILES_BACKUP_DIR` | `~/.dotfiles-backup-<时间戳>` | 冲突文件备份目录 |

## 实现说明

- 条目表 `LINK_TABLE` 和分组表 `GROUP_TABLE` 都在脚本顶部,新增/删除受管条目改这里即可
- 刻意保持 bash 3.2 兼容(macOS 系统自带 bash),空数组 + `set -u` 的旧 bash 陷阱用纯字符串迭代规避
- 链接目标固定为 `$DOTFILES/$src` 的绝对路径,`status` 据此判断 `STALE`