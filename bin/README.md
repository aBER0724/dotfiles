# bin

`dotfiles` CLI — 一条命令管理 `~` 与 `~/dotfiles` 之间的所有符号链接。

## 目录结构

```
bin/
└── dotfiles    # bash 3.2 兼容的单文件脚本,零依赖
```

## 安装

```bash
ln -sf ~/dotfiles/bin/dotfiles ~/.local/bin/dotfiles
```

## 用法

```
dotfiles {list|status|link|install|deps} [name...]
```

| 命令 | 说明 |
|------|------|
| `list` | 列出所有受管条目(name → 源 → 目标) |
| `status [name...]` | 显示链接状态:`ok` / `STALE` / `CONFLICT` / `missing`(默认全部) |
| `link [name...]` | 创建缺失链接;目标已有真实文件时备份到 `~/.dotfiles-backup-<时间戳>` 再替换 |
| `install [name...]` | `link` + 该条目所属分组的运行时依赖(herdr 插件、zsh 依赖等) |
| `deps` | 只装依赖不碰链接(已链接的机器用) |

### 分组

`dotfiles link pi`、`dotfiles install wm` 等会展开为组内全部条目:

| 分组 | 成员 |
|------|------|
| `pi` | pi-settings, pi-models, pi-extensions |
| `zsh` | zshrc, zshenv, zprofile, shinit, p10k |
| `herdr` | herdr |
| `wm` | niri, nbshell |

`install` 的依赖安装策略:

- herdr / zsh / clavis / nbshell 只在显式指定(或未指定 = 全部)时才跑其安装脚本,避免无谓的安装抖动
- pi 无安装脚本,只提示缺少 `~/.pi/agent/auth.json` 时的创建方法

## 环境变量

| 变量 | 默认 | 说明 |
|------|------|------|
| `DOTFILES_DIR` | `~/dotfiles` | 仓库路径 |
| `DOTFILES_BACKUP_DIR` | `~/.dotfiles-backup-<时间戳>` | 冲突文件备份目录 |

## 实现说明

- 条目表 `LINK_TABLE` 和分组表 `GROUP_TABLE` 都在脚本顶部,新增/删除受管条目改这里即可
- 刻意保持 bash 3.2 兼容(macOS 系统自带 bash),空数组 + `set -u` 的旧 bash 陷阱用纯字符串迭代规避
- 链接目标固定为 `$DOTFILES/$src` 的绝对路径,`status` 据此判断 `STALE`