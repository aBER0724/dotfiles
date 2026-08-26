# nvim — LazyVim

基于 [LazyVim](https://github.com/LazyVim/LazyVim) starter 的 Neovim 配置,跨设备同步。
启动 LazyVim 会自动安装全部插件,无需手动 clone。

## 来源

- [LazyVim](https://github.com/LazyVim/LazyVim) — 核心框架(starter 模板)
- `colors/nbshell.lua` — 自研动态配色(读 `~/.config/nbshell/palette.sh`,随 `Alt+T` 主题切换自动变色,替换默认 tokyonight)
- 见下方「插件清单」完整来源列表

## 目录结构

```
nvim/
├── init.lua          # 入口
├── lazy-lock.json    # 插件 commit 锁(运行时生成,不同步)
├── lazyvim.json      # 安装版本/计数器(运行时生成,不同步)
├── kuuga.txt         # dashboard ASCII art
├── stylua.toml       # Lua 格式化配置
└── lua/
    ├── config/       # options / keymaps / autocmds / lazy 引导
    └── plugins/      # 自定义插件配置(覆盖或扩展 LazyVim 默认)
```

## 已启用的 LazyVim extras

在 `lua/config/lazy.lua` 中启用:

| extra | 说明 |
|-------|------|
| `lazyvim.plugins.extras.ai.claudecode` | Claude Code 集成 |
| `lazyvim.plugins.extras.editor.inc-rename` | 增量重命名 |
| `lazyvim.plugins.extras.lang.astro` | Astro 支持 |
| `lazyvim.plugins.extras.lang.json` | JSON 支持 |
| `lazyvim.plugins.extras.lang.markdown` | Markdown 支持 |
| `lazyvim.plugins.extras.lang.python` | Python 支持 |
| `lazyvim.plugins.extras.lang.tailwind` | Tailwind 支持 |
| `lazyvim.plugins.extras.lang.toml` | TOML 支持 |
| `lazyvim.plugins.extras.lang.yaml` | YAML 支持 |

## 自定义插件

| 文件 | 插件 | 用途 |
|------|------|------|
| `lua/plugins/bufferline.lua` | [akinsho/bufferline.nvim](https://github.com/akinsho/bufferline.nvim) | 顶部标签栏美化 |
| `lua/plugins/colorscheme.lua` | LazyVim 默认 + `colors/nbshell.lua` | 主题(动态跟随 nbshell;`autocmds.lua` 轮询 palette.sh) |
| `lua/plugins/dashboard.lua` | [folke/snacks.nvim](https://github.com/folke/snacks.nvim) | Dashboard(带 kuuga.txt ASCII art) |
| `lua/plugins/neo-tree.lua` | [nvim-neo-tree/neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) | 文件树 |
| `lua/plugins/smart-splits.lua` | [mrjones2014/smart-splits.nvim](https://github.com/mrjones2014/smart-splits.nvim) | 分屏移动/缩放 |
| `lua/plugins/example.lua` | 示例模板(含 gruvbox/trouble 注释参考) | 新插件配置的样板 |

## 自定义 Keymaps

`lua/config/keymaps.lua` 与 `lua/plugins/keymaps.lua`:

| 模式 | 按键 | 动作 |
|------|------|------|
| normal/insert/visual | `<C-s>` | 保存文件(`:w`) |

其余日常操作全部走 LazyVim 默认键位,见 [LazyVim Keymaps](https://lazyvim.github.io/keymaps)。

## 为什么 lazy-lock.json / lazyvim.json 不同步

这两个文件由 LazyVim 在每次插件检查/更新时自动重写:
- `lazy-lock.json` — 40+ 插件的 commit 锁定清单,各设备插件版本彼此独立
- `lazyvim.json` — `version`/`install_version` 递增计数器,跨设备永不收敛

所以它们被 gitignore,各设备保留自己的本地插件状态;配置(lua/)才是同步的内容。

## 新设备安装

```bash
# 确保 Neovim ≥ 0.9 已安装
dotfiles link nvim        # 建立 ~/.config/nvim -> ~/dotfiles/nvim 符号链接
nvim                      # 首次启动自动安装全部插件
```

> 注意:这是 LazyVim 官方 starter 模板(含 LICENSE),非传统 vimrc 配置。