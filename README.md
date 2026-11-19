# dotfiles

Personal configuration files.

## Contents

| Config | Description |
|--------|-------------|
| [aerospace](/aerospace) | AeroSpace tiling window manager (macOS) |
| [niri](/niri) | Niri scrollable-tiling compositor — AeroSpace-style bindings, scripts/ |
| [nbshell](/nbshell) | [nbshell](https://github.com/nerdislb/nbshell) Nerd Font/TUI Quickshell shell for niri; pinned user-local installer + synced config |
| [clavis](/clavis) | Previous StatIndet/Clavis shell retained as a manual rollback |
| [waybar](/waybar) | Legacy Waybar configuration retained as a second manual rollback |
| [hypr](/hypr) | Hyprland (Omarchy) frosted-glass blur shared by every Omarchy machine — `require("hypr.blur")` after Omarchy's toggles, because the "Animations off" flag disables blur |
| [omarchy](/omarchy) | Stock Omarchy bar on a Mac host — minimal layout (workspaces · active window · tray · clock), a click-to-open tray widget, and a spacer keeping the clock clear of the macOS privacy dot; a `theme-set` hook that reloads kitty so running terminals take the new palette |
| [kaku](/kaku) | Terminal (WezTerm-based) |
| [kitty](/kitty) | Kitty terminal — Kaku-inspired port (fonts, Kaku Dark, Cmd keymap), palette follows Omarchy with a final `include` of `~/.local/state/omarchy/current/theme/kitty.conf` |
| [nvim](/nvim) | Neovim (LazyVim) |
| [lazygit](/lazygit) | lazygit — side-by-side (delta) diff by default, `|` cycles renderers |
| [fastfetch](/fastfetch) | System info |
| [zsh](/zsh) | Zsh config (zshrc, zprofile, zshenv, p10k) |
| [pi-agent](/pi-agent) | pi coding agent — syncs settings, models, and extensions; API keys stay per-device |
| [herdr](/herdr) | Terminal workspace manager — syncs config.toml, plugin inventory, and the herdr-lazygit pane override (side-by-side diffs) |
| [clash-verge](/clash-verge) | Clash Verge Rev — global extension script that rebuilds the FlClash proxy-group set (入口 / 17 地区 / 14 服务) from whatever nodes the subscription has |
| [bin](/bin) | `dotfiles` CLI — one command to link/status/install all configs; `mate` drives pi/claude sub-agents from one shell |

## Theme

Palette is owned by [nbshell](/nbshell)(`Alt+T` 切换主题):`theme-sync.py` 导出 `palette.sh`,
`theme-hook.sh` 同步 Kitty / btop / fcitx5 / herdr / nvim / GTK3+GTK4 / XDG portal / niri 焦点环,
并生成 Chromium theme extension(工具栏/omnibox/新标签页配色)—— 经 chromium-controller 在运行中热重载,
终端冷启动时由 `--load-extension` 兜底;网页明暗(`prefers-color-scheme`)经 portal 即时跟随。

候选窗主题跟着桌面走,不再在仓库里钉死:连接了 nbshell 配置(`linux niri`)时用 nbshell 的
`theme-hook.sh` 生成的 `Nbshell` 主题;stock Omarchy 上用 Omarchy 自己生成的主题
(`omarchy-theme-set-fcitx5` 每次换主题都会重写 `~/.local/share/fcitx5/themes/omarchy`)。
[fcitx5/classicui.conf](/fcitx5/classicui.conf) 只是种子,`fcitx5/install.sh` 按桌面填 `Theme`,
在 fcitx5-configtool 里手动选过的主题不会被覆盖。

`~/.config/fcitx5/conf/classicui.conf` 本身是运行时状态(被 [fcitx5/conf/.gitignore](/fcitx5/conf/.gitignore)
忽略):它只在仓库里作为种子存在,由 `fcitx5/install.sh` 在缺文件时复制过去并把 `Theme` 指到桌面生成的主题。
所以它一旦被删(比如某次 `git pull` 移除了曾经被跟踪的副本,或换了机器只做了 `dotfiles link fcitx`),
候选窗就退回 stock 主题,而且换主题也不会自己长回来 —— 重写主题目录的钩子不带 `--activate`。
恢复:

```bash
dotfiles install fcitx        # 跑 fcitx5/install.sh:补种子 + 指主题 + 重载 classicui
```

只想修主题、不动 rime 的话,两步即可:`cp ~/dotfiles/fcitx5/classicui.conf ~/.config/fcitx5/conf/`
然后 `omarchy-theme-set-fcitx5 --activate`。验证:`busctl --user call org.fcitx.Fcitx5 /controller
org.fcitx.Fcitx.Controller1 GetConfig s 'fcitx://config/addon/classicui'` 里应看到 `"Theme" s "omarchy"`。

## Setup

```bash
git clone https://github.com/aBER0724/dotfiles.git ~/dotfiles
bash ~/dotfiles/bin/dotfiles setup auto
# The setup links the CLI to ~/.local/bin/dotfiles. If this shell does not
# already include ~/.local/bin (for example a fresh Bash login), enable it once:
export PATH="$HOME/.local/bin:$PATH"
dotfiles setup auto

# Or select the operating system and Linux environment explicitly:
bash ~/dotfiles/bin/dotfiles setup macos
bash ~/dotfiles/bin/dotfiles setup linux omarchy  # Arch/Omarchy desktop
bash ~/dotfiles/bin/dotfiles setup server         # headless Ubuntu/Debian, root supported

# Fine-grained management after setup:
dotfiles status
dotfiles link
dotfiles deps fastfetch pi
dotfiles install wm
```

`setup` installs the primary stack, links its configuration, and runs user-level plugin/install scripts. Linux is divided into environment profiles:

- `linux omarchy`: the default Arch profile for stock Omarchy (Hyprland/uwsm) — Kitty, fcitx5+Rime input method, native pacman packages. Omarchy itself provides the desktop stack (waybar, hypridle, autostart); only its bar config is synced, see [omarchy/](omarchy/README.md).
- `linux niri`: the custom Niri + nbshell desktop stack — everything in `omarchy` plus niri, nbshell, and `nbshell/packages.arch.txt`.
- `server` (or `linux server`): a headless Ubuntu/Debian stack containing only the shared terminal tools (Zsh, Neovim, Fastfetch, pi, and herdr). It supports root-owned server environments, uses `apt-get` plus official Linux release binaries, and deliberately excludes Homebrew, Niri, nbshell, Kitty, input methods, and desktop services.
- `linux auto` (or plain `setup auto`): selects `omarchy` on Arch derivatives and `server` on Ubuntu/Debian.
macOS and the Omarchy profile bootstrap Homebrew when missing. The server profile avoids Homebrew so it can run directly under root and installs Herdr, Yazi, and Fastfetch from their official Linux releases. Existing conflicting files are backed up before linking. Starting services or GUI apps, changing the login shell, and creating the pi API key remain manual. The old `setup arch` command remains as a compatibility alias for `setup linux omarchy`.
### Niri + nbshell

The `wm` group uses nbshell as the active desktop shell. Its visual language is
terminal-oriented: square one-pixel borders, Nerd Font symbols, compact text surfaces and
block meters instead of Material cards, shadows and circular resource charts. Clavis and
Waybar remain in the repository only as manual rollback configurations.

`nbshell/install.sh` pins the upstream revision, validates its scripts and installs the
runtime, CLI, themes and user service entirely below `~/.local`/`~/.config`. It never calls
`sudo` or a package manager. The synchronized default uses the local Futurism palette and
wallpaper, Chinese locale, 24-hour time, named Niri workspaces and TUI block meters.
Optional Arch dependencies are recorded in `nbshell/packages.arch.txt`. The installer checks
the list and prints the manual `sudo pacman -S --needed ...` command when packages are
missing, but never executes it. `tuned` additionally requires the one-time manual command
`sudo systemctl enable --now tuned.service`.

```bash
systemctl --user enable --now nbshell.service  # start and enable
nbshell stop                                   # stop
nbshell launcher                               # application launcher
nbshell dashboard                              # dashboard
~/.config/nbshell/theme-next-sync                  # switch theme + sync Kitty/nvim/herdr/pi/lazygit/yazi
nbshell wallpaper pick                         # wallpaper picker
nbshell notify center                          # notification center
```

Current niri shortcuts: `Alt+Space` launcher, `Alt+T` theme switch (cycles + syncs downstream
apps), `Alt+Shift+T` wallpaper picker, `Alt+Ctrl+T` dashboard, `Alt+N` notifications and
`Alt+Escape` power menu.

Manual Clavis rollback:

```bash
systemctl --user disable --now nbshell.service
PATH="$HOME/.local/bin:$PATH" QML_IMPORT_PATH="$HOME/.local/lib/qt6/qml" key shell --daemon
```

## pi

Config in `~/.pi/agent/`, symlinked from [pi-agent/](pi-agent/README.md).

- **Synced**: `settings.json` (plugins list, theme, defaults), `models.json` (third-party providers), `extensions/` (extension configs)
- **Not synced**: `auth.json` (API keys), package caches, sessions
- **API keys**: third-party key-based providers, no login — set per device in `~/.pi/agent/auth.json` or env var
- **Plugins**: declared by source in `settings.json`, auto-reinstalled on first launch
- **Skills**: not synced — `~/.agents/skills` links to the machine-local magpie library (`~/.config/magpie/library/skills`); `dotfiles link pi` keeps the link pointed there where that directory exists, and `skip`s (pruning a stale dead link) on machines without magpie; the old `agent-skills` submodule was removed

## herdr

Config in `~/.config/herdr/`, synced from [herdr/](herdr/README.md).

- **Synced**: `config.toml` (theme, keybindings), `plugins.txt` (plugin sources)
- **Not synced**: installed plugins, logs, session state
- **Plugins**: installed by source in `plugins.txt`; on a new device one command installs them all:

  `setup auto` 会安装 herdr 核心；macOS 通过 Homebrew cask 安装 `herdr-scratch`，Linux 则由 `herdr plugin install macintacos/herdr-scratch` 从源码构建。随后运行插件清单。Linux 不使用该 cask，因为 Homebrew cask 的 macOS quarantine hook 与 Linux `xattr` 不兼容。插件构建需要 Go；失败后可重跑 `bash ~/dotfiles/herdr/install-plugins.sh`。