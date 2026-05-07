# Kaku 键盘快捷键可视化（来自 `kaku.lua`）

> 来源：`~/.config/kaku/kaku.lua` 里的 `config.keys`。

## 方向键 / Vim `h j k l`“聚类图”（最常用）

| 组合键 | ← Left | → Right | ↑ Up | ↓ Down |
|---|---|---|---|---|
| `⌥ Opt` + 方向键 | 词级后退（发送 `Alt+b`） | 词级前进（发送 `Alt+f`） | — | — |
| `⌘ Cmd` + 方向键 | 行首（发送 `Ctrl+a`） | 行尾（发送 `Ctrl+e`） | — | — |
| `⌘ Cmd` + `⌥ Opt` + 方向键 / `h j k l` | 激活左侧分屏 | 激活右侧分屏 | 激活上方分屏 | 激活下方分屏 |
| `⌘ Cmd` + `⌃ Ctrl` + 方向键 / `h j k l` | 向左缩放/扩展 5 | 向右缩放/扩展 5 | 向上缩放/扩展 5 | 向下缩放/扩展 5 |

> Vim 方向对应：`h=←`、`j=↓`、`k=↑`、`l=→`。

## Backspace / Enter“聚类图”

| 组合键 | 效果 |
|---|---|
| `⌘ Cmd` + `Backspace` | 删除到行首（发送 `Ctrl+u`） |
| `⌥ Opt` + `Backspace` | 删除一个单词（发送 `Ctrl+w`） |
| `⌘ Cmd` + `Enter` | 仅插入换行（发送 `\n`） |
| `Shift` + `Enter` | 仅插入换行（发送 `\n`） |
| `⌘ Cmd` + `Shift` + `Enter` | 分屏放大/还原（Toggle Pane Zoom） |

## 全量快捷键（按功能分组）

### 应用 / 窗口

| 组合键 | 动作 |
|---|---|
| `⌘ Cmd` + `R` | 清屏 + 清滚动回溯（`Ctrl+L` + `ClearScrollback`） |
| `⌘ Cmd` + `Q` | 退出应用 |
| `⌘ Cmd` + `N` | 新窗口 |
| `⌘ Cmd` + `M` | 最小化窗口（Hide） |
| `⌘ Cmd` + `H` | 隐藏应用（HideApplication） |
| `⌘ Cmd` + `⌃ Ctrl` + `F` | 切换全屏 |
| `⌘ Cmd` + `Shift` + `R` | 重载配置 |
| `⌘ Cmd` + `Shift` + `.` | 重载配置 |

### 字体

| 组合键 | 动作 |
|---|---|
| `⌘ Cmd` + `=` | 字号增大 |
| `⌘ Cmd` + `-` | 字号减小 |
| `⌘ Cmd` + `0` | 字号重置 |

### Tab

| 组合键 | 动作 |
|---|---|
| `⌘ Cmd` + `T` | 新建 Tab |
| `⌘ Cmd` + `Shift` + `[` | 上一个 Tab |
| `⌘ Cmd` + `Shift` + `]` | 下一个 Tab |
| `⌘ Cmd` + `1` ~ `9` | 切换到第 1~9 个 Tab |
| `⌘ Cmd` + `Shift` + `W` | 关闭当前 Tab（不确认） |

### 分屏（Pane）

| 组合键 | 动作 |
|---|---|
| `⌘ Cmd` + `W` | “智能关闭”：有多个 Pane 就关 Pane；否则关 Tab（都不确认） |
| `⌘ Cmd` + `D` | 分屏：左右分（WezTerm `SplitHorizontal`） |
| `⌘ Cmd` + `Shift` + `D` | 分屏：上下分（WezTerm `SplitVertical`） |
| `⌘ Cmd` + `⌥ Opt` + 方向键 / `h j k l` | 在分屏间移动焦点 |
| `⌘ Cmd` + `Shift` + `Enter` | 放大/还原当前 Pane |
| `⌘ Cmd` + `⌃ Ctrl` + 方向键 / `h j k l` | 调整分屏尺寸（步进 5） |

### 光标移动 / 编辑（发给 shell 的按键）

| 组合键 | 实际发送 |
|---|---|
| `⌥ Opt` + `←` | `Alt+b` |
| `⌥ Opt` + `→` | `Alt+f` |
| `⌘ Cmd` + `←` | `Ctrl+a` |
| `⌘ Cmd` + `→` | `Ctrl+e` |
| `⌘ Cmd` + `Backspace` | `Ctrl+u` |
| `⌥ Opt` + `Backspace` | `Ctrl+w` |

## 鼠标（顺手也放这）

| 操作 | 效果 |
|---|---|
| 左键选择后松开 | 复制选区（并支持在鼠标位置完成选择/打开链接） |
| `⌘ Cmd` + 左键松开 | 打开鼠标位置的链接 |
