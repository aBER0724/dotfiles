# niri

[niri](https://github.com/YaLTeR/niri) — 可滚动平铺 Wayland 合成器配置。

按键风格对齐 macOS / AeroSpace:**主键 = `Alt`**。修改后 niri 自动热重载,无需重启。

## 目录结构

```
niri/
├── config.kdl              # 主配置(输入、输出、启动项、全部按键绑定)
├── clavis/cursor.kdl       # 鼠标指针主题 —— Clavis 托管,手动改动会被覆盖
└── scripts/screenshot.sh   # 截图助手(region / full)
```

## 配置要点

- **输入**:`us` 布局 + `ctrl:nocaps`;触摸板轻点/自然滚动;鼠标 `focus-follows-mouse`
- **显示器**:DP-2 外接屏固定 `2560x1440@100`;其余沿用默认
- **启动项**:`nbshell.service`(桌面 Shell)、`fcitx5`(输入法)、`cc-switch`
- **校验**:`niri validate`(改完可先校验再切过去)

## 按键绑定(config.kdl `binds`)

### 窗口

| 按键 | 动作 |
|------|------|
| `Alt+Return` | 打开 alacritty |
| `Alt+C` | 关闭窗口(Cmd+W 习惯) |
| `Alt+F` / `Alt+Shift+F` | 全屏 / 浮动切换 |
| `Alt+M` / `Alt+Shift+M` | 最大化列 / 居中窗口 |
| `Alt+H/J/K/L` | 按列/窗口移动焦点(HL 列、JK 行) |
| `Alt+Ctrl+H/L` | 跨显示器聚焦 |
| `Alt+Shift+H/J/K/L` | 移动列/窗口 |
| `Alt+Ctrl+Shift+H/L` | 列移到另一显示器 |
| `Alt+Home/End` | 列移到最左/最右 |
| `Alt+Shift+Minus/Equal` | 列宽 ±10% |
| `Alt+Ctrl+1/2` | 循环列宽预设 |

### 工作区(命名,数字 + QWER)

| 按键 | 动作 |
|------|------|
| `Alt+1..5` / `Alt+Q/W/E/R` | 聚焦工作区 |
| `Alt+Shift+1..5` / `Alt+Shift+Q/W/E/R` | 窗口移到指定工作区 |
| `Alt+Tab` | 上一个工作区(往返) |

### 面板入口(经 nbshell)

| 按键 | 动作 |
|------|------|
| `Alt+Space` | nbshell 启动器 |
| `Alt+T` | 切换主题并同步下游(theme-next-sync: nvim/herdr/pi/lazygit/yazi/alacritty) |
| `Alt+Shift+T` | 壁纸切换 |
| `Alt+Escape` | 电源菜单 |

## 截图

依赖 `grim` + `slurp`(可选 `wl-clipboard` 复制到剪贴板):

```bash
~/dotfiles/niri/scripts/screenshot.sh region   # 交互框选
~/dotfiles/niri/scripts/screenshot.sh full     # 全屏
```

默认保存到 `~/Pictures/Screenshots/<时间戳>.png`,并 `notify-send` 提示。