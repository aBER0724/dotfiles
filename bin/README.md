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
| `setup [auto\|macos\|arch]` | 检测或指定系统，一键安装并配置主力栈 |

## 系统一键安装

```bash
dotfiles setup auto   # 自动识别 macOS 或 Arch
dotfiles setup macos  # 仅允许在 macOS 执行
dotfiles setup arch   # 仅允许在 Arch/Arch 衍生系统执行
```

- 共享主力配置：dotfiles CLI、Zsh、Neovim、Fastfetch、pi、herdr。
- macOS 额外安装并链接 AeroSpace 和 Kitty；缺少 Homebrew 时从官方固定 URL 自动安装。
- Arch 额外安装并链接 Niri、nbshell 和 Kitty；先通过 `sudo pacman -S --needed` 安装 Homebrew 前置依赖、配置软件、herdr 插件所需的 Rust/Cargo 与 Yazi，以及 `nbshell/packages.arch.txt`，再按需引导 Linuxbrew 并安装 brew-only 软件。
- Arch 不安装 `herdr-scratch` cask，也不安装 `python-xattr` 来模拟 macOS `xattr`；Linux 由 herdr 的插件安装器从源码构建 scratch。
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

- macOS / 已安装 Homebrew 的 Linux 使用 Homebrew；Arch Linux 使用 `sudo pacman -S --needed`
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