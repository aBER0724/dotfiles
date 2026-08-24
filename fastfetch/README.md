# fastfetch

[fastfetch](https://github.com/fastfetch-cli/fastfetch) — 极简系统信息工具(neofetch 继任),配置 + 自绘 logo。

## 来源

- [fastfetch](https://github.com/fastfetch-cli/fastfetch) — 本体(brew:`brew install fastfetch`)
- `kuuga.png` — 自定义 logo 图片(chafa 渲染)
- `logo.txt` — ASCII art 字号备选 logo

## 目录结构

```
fastfetch/
├── config.jsonc   # 结构/logo/显示模块配置
├── kuuga.png      # 图片 logo(chafa,宽 30 高 18)
└── logo.txt       # ASCII logo 备选
```

配置要点:`logo.source` 指向 `~/.config/fastfetch/kuuga.png`,`type: chafa` 图片渲染。

## 新设备安装

```bash
brew install fastfetch        # 或 Linux: 各发行版包/二进制
dotfiles link fastfetch       # ~/.config/fastfetch -> ~/dotfiles/fastfetch
fastfetch                     # 立即显示系统信息
```

> 纯展示用途,无运行时状态,全部内容可同步。