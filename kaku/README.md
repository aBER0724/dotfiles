# kaku

[Kaku](https://github.com/EgoistDeveloper/Kaku) 终端(WezTerm 引擎)配置,跨设备同步。
`kaku.lua` 是主配置文件(WezTerm 风格 Lua),另含内置 AI assistant 配置、tmux 集成与统计脚本。

## 来源

- [Kaku](https://github.com/EgoistDeveloper/Kaku) — 终端本体(macOS)
- Kaku App 内置 zsh 插件(fast-syntax-highlighting、zsh-autosuggestions、zsh-completions、zsh-z)— vendored 自安装包,见 `zsh/`
- 键盘键位来自 kaku.lua 的 `config.keys`,可视化见 keyboard-map.md

## 目录结构

```
kaku/
├── kaku.lua            # 主配置:主题、字体、键位、窗口(同步)
├── keyboard-map.md     # 键位可视化文档(维护用)
├── stats.sh            # 使用统计脚本
├── assistant.toml      # 内置 AI assistant 配置
├── tmux/               # tmux 集成
└── zsh/                # kaku 的 zsh 启动(sh)集成
```

## 自定义 Keymaps(来自 kaku.lua)

完整键位见 `keyboard-map.md`。常用聚类:

| 组合键 | 动作 |
|--------|------|
| `⌥ Opt` + `←`/`→` | 词级后退/前进(发 `Alt+b`/`Alt+f`) |
| `⌘ Cmd` + `←`/`→` | 行首/行尾(发 `Ctrl+a`/`Ctrl+e`) |
| `⌘ Cmd` + `⌥ Opt` + 方向键 | 激活左/右/上/下分屏 |
| `⌘ Cmd` + `⌃ Ctrl` + 方向键 | 缩放/扩展分屏(步进 5) |
| `⌘ Cmd` + `Backspace` | 删到行首(发 `Ctrl+u`) |
| `⌥ Opt` + `Backspace` | 删一个词(发 `Ctrl+w`) |
| `⌘ Cmd` + `Enter` / `Shift`+`Enter` | 仅插入换行 |
| `⌘ Cmd` + `Shift` + `Enter` | 分屏放大/还原 |
| `⌘ Cmd` + `R` | 清屏+清回溯 |
| `⌘ Cmd` + `D` / `Shift`+`D` | 左右 / 上下分屏 |
| `⌘ Cmd` + `T` | 新建 tab |
## 真实配置 vs 运行时文件

| 文件 | 处理 |
|------|------|
| `kaku.lua` | 真实配置,**同步** |
| `keyboard-map.md` | 维护文档,**同步** |
| `tmux/` `zsh/` 的启动文件 | 集成,**同步** |
| `.kaku_font_size` `.kaku_config_version` | 运行时自动写,**gitignore** |
| `session_content/` `ai_*` `last_*` `state.json` | 会话/状态,**gitignore** |

## 新设备安装

```bash
# 1. 安装 Kaku(macOS;见 Kaku 官方安装)
# 2. 链接配置(或 dotfiles link kaku)
dotfiles link kaku
# 3. 打开 Kaku,它会读 ~/.config/kaku/kaku.lua
```

> 配置与运行时状态分离:改动后各设备 pull 即可;字号/会话等本地状态不会互相踩。