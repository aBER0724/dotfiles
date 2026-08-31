# fastfetch

[fastfetch](https://github.com/fastfetch-cli/fastfetch) 是轻量的系统信息展示工具。本配置使用紧凑的 Nerd Font 图标布局，并通过 kitty 原生图像协议显示 PNG Logo。

## 文件

```text
fastfetch/
├── config.jsonc   # Logo、模块、图标与配色配置
├── rx.png         # 当前使用的 PNG Logo
├── kuuga.png      # 备用图片 Logo
└── logo.txt       # 备用 ASCII Logo
```

## Logo 渲染

当前配置：

```jsonc
"logo": {
  "source": "~/.config/fastfetch/rx.png",
  "type": "kitty-direct",
  "width": 30,
  "preserveAspectRatio": true,
  "padding": {
    "top": 4,
    "left": 1,
    "right": 2
  }
}
```

- `kitty-direct` 使用 kitty graphics protocol 直接显示图片，不转换成字符画。
- 只固定宽度并启用 `preserveAspectRatio`，避免在非正方形终端单元格中拉伸图片。
- `padding.top: 4` 将图片向下移动，使其与右侧信息列表大致垂直居中。
- 如果使用不支持 kitty 图像协议的终端，可将 `type` 改为 `chafa`。

## 展示内容

右侧依次显示用户与主机、系统、内核、软件包、Shell、终端、窗口管理器、光标、终端字体、运行时间、日期、媒体、播放器和 ANSI 色板。模块图标需要 Nerd Font。

## 安装

```bash
brew install fastfetch        # Linux 可使用发行版软件包
dotfiles link fastfetch       # ~/.config/fastfetch -> ~/dotfiles/fastfetch
fastfetch
```

配置和图片均可随 dotfiles 同步，不包含运行时状态。