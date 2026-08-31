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

- 默认使用 `kitty-direct` 和 `padding.top: 4`，保留物理机上原本的垂直居中效果。
- `ff` 在 SSH 会话中会通过 `--kitty ~/.config/fastfetch/rx.png` 同时显式覆盖图片类型和来源，再使用 `--logo-padding-top 0`。只传 `--logo-type kitty` 会丢失配置中的 `kitty-direct` 图片源并回退到系统 ASCII Logo。
- 因此物理机与 SSH 使用各自的渲染方式和偏移量，不再让同一组参数互相影响。
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