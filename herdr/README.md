# herdr

[herdr](https://herdr.dev) 终端工作区管理器(面向 AI coding agent),跨设备同步。
此为 v0.8.2 时代的配置;插件通过 `plugins.txt` 清单重装,不提交安装产物。

## 来源

- [herdr](https://herdr.dev) — 本体(official formula `brew install herdr`)
- [herdr-scratch](https://github.com/macintacos/tap) — 3rd-party tap 提供的 scratch 二进制(见下)
- 8 个 GitHub 插件 + 1 个本地插件,见「插件清单」

## 目录结构

```
herdr/
├── config.toml          # 主题 / 键位 / UI(同步)
├── plugins.txt          # 插件清单:owner/repo + 固定 ref(同步)
├── gen-plugins.sh       # 设备上改动插件后重新生成 plugins.txt
├── install-plugins.sh   # 新设备按清单重装全部插件
└── scratch/             # 本地插件 user.scratch 的 manifest
```

## 插件清单(来自 plugins.txt)

| 插件 ID | 来源仓库 | 说明 |
|---------|---------|------|
| `dave.token-dashboard` | [Davidcreador/herdr-token-dashboard](https://github.com/Davidcreador/herdr-token-dashboard) | token 用量面板(Go 构建) |
| `herdr-lazygit` | [crokily/herdr-lazygit](https://github.com/crokily/herdr-lazygit) | lazygit 集成 |
| `herdr-navigator` | [thanhdat77/herdr-navigator](https://github.com/thanhdat77/herdr-navigator) | 跳转面板 |
| `herdr-plugin-renamer` | [wenhanweime/herdr-plugin-renamer](https://github.com/wenhanweime/herdr-plugin-renamer) | 插件重命名 |
| `jhochenbaum.hunkdiff` | [jhochenbaum/herdr-hunk-diff](https://github.com/jhochenbaum/herdr-hunk-diff) | diff 高亮(Go 构建) |
| `mirror` | [nikok6/herdr-mirror](https://github.com/nikok6/herdr-mirror) | 远程镜像/同步面板 |
| `ray.file-explorer` | [speardragon/herdr-yazi](https://github.com/speardragon/herdr-yazi) | yazi 文件浏览器 |
| `ray.plugin-manager` | [speardragon/herdr-plugin-manager](https://github.com/speardragon/herdr-plugin-manager) | 插件管理器 UI |
| `user.scratch` | 本地 `scratch/herdr-plugin.toml` + [macintacos/tap](https://github.com/macintacos/tap) | 弹出式 scratch shell(Go) |

> 每个 GitHub 插件都固定在 `plugins.txt` 里的指定 ref,保证所有设备装到同一版本。

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

## 为什么 plugins.json 不同步

herdr 的 `plugins.json` 记录绝对安装路径(`/Users/aber/.config/herdr/plugins/...`),
机器相关。改为同步 `plugins.txt`(owner/repo + ref),新设备一条命令重装。

## 新设备安装

```bash
# 1. required binaries — Linux and macOS both support Homebrew:
brew install herdr                       # official core formula
brew install macintacos/tap/herdr-scratch  # 3rd-party tap: binary for the scratch plugin
# (no brew? herdr's own installer works on both too: curl -fsSL https://herdr.dev/install.sh | sh)

# 2. link config
ln -sf ~/dotfiles/herdr/config.toml ~/.config/herdr/config.toml

# 3. install ALL plugins from the inventory (GitHub at pinned ref + local link)
bash ~/dotfiles/herdr/install-plugins.sh
```

> 有 Go 构建步骤的插件(token-dashboard、hunkdiff、scratch)需要机器上有 Go 工具链;
> 脚本会先做 preflight 检查并给出警告,单个插件失败不会阻塞其余安装。