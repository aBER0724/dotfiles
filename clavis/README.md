# clavis

[Clavis](https://github.com/StatIndet/quickshell)(StatIndet Quickshell 系)—— 上一代桌面 Shell,已被 [nbshell](../nbshell/) 取代。

**保留在仓库里仅作手动回滚配置**,不再主动使用。

## 目录结构

```
clavis/
├── install.sh                  # 用户级安装器(绝不 sudo);含 key CLI / keytop 构建
├── config/                     # 同步配置(链接到 ~/.config/clavis/)
│   ├── config.json             # 壁纸、桌面后端、过渡动画等
│   ├── idle-policy.json        # 空闲/熄屏策略
│   ├── quick-toggles.json      # 快捷开关
│   ├── tray.json               # 系统托盘
│   └── ui-preferences.json     # UI 偏好
├── application-icon-query.patch    # 应用图标查询补丁
└── nerd-font-icons.patch           # Nerd Font 图标补丁(~90KB)
```

## 回滚(从 nbshell 换回 Clavis)

```bash
systemctl --user disable --now nbshell.service
PATH="$HOME/.local/bin:$PATH" QML_IMPORT_PATH="$HOME/.local/lib/qt6/qml" key shell --daemon
```

## 安装(仅回滚场景需要)

`clavis/install.sh` 固定上游 revision(quickshell / key-cli / keytop),全部装到 `~/.local` 之下,从不调用 `sudo`、pacman、paru 或 yay。构建用系统 Qt6,`CLAVIS_PREFIX` / `CLAVIS_BUILD_JOBS` 可覆盖默认。

```bash
bash ~/dotfiles/clavis/install.sh    # 或 dotfiles install clavis
```

## 备注

- `config/` 内路径可能残留 `/home/aber/...` 等机器相关绝对路径,新设备需按实际调整
- 补丁文件是相对固定上游版本的本地修改,升级上游时需重新评估是否仍适用