# aerospace

[Aerospace](https://github.com/nikitabobko/AeroSpace) — macOS 平铺窗口管理器(Tiling Window Manager)配置。

## 来源

- [AeroSpace](https://github.com/nikitabobko/AeroSpace) — 本体(brew:`brew install --cask nikitabobko/tap/aerospace`)

## 配置要点(aerospace.toml)

| 项 | 值 | 说明 |
|----|----|------|
| `start-at-login` | `true` | 登录自启 |
| 布局 | `tiles` | 平铺布局 |
| 容器 | 归一化 | flatten + orientation 归一化开启 |
| gaps | 全 0 | 无缝隙贴边风格 |
| key-mapping | `qwerty` | 标准键位 |
| `on-focused-monitor-changed` | `move-mouse monitor-lazy-center` | 切屏鼠标跟随 |

### 快捷键

除自定义外,全部走 AeroSpace 默认键位(`Alt` 前缀),见官方 [Keybindings](https://github.com/nikitabobko/AeroSpace/blob/main/docs/commands.md)。

## 新设备安装

```bash
brew install --cask nikitabobko/tap/aerospace
dotfiles link aerospace    # ~/.aerospace.toml -> ~/dotfiles/aerospace/aerospace.toml
# 启动 AeroSpace 后配置自动生效
```

> 仅 macOS 可用;Linux 机器无需同步此目录(`dotfiles install` 不指定它即可)。