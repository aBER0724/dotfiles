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
| [kaku](/kaku) | Terminal (WezTerm-based) |
| [nvim](/nvim) | Neovim (LazyVim) |
| [fastfetch](/fastfetch) | System info |
| [zsh](/zsh) | Zsh config (zshrc, zprofile, zshenv, p10k) |
| [pi-agent](/pi-agent) | pi coding agent — syncs settings, models, extensions; API keys stay per-device |
| [herdr](/herdr) | Terminal workspace manager — syncs config.toml + plugin inventory |
| [bin](/bin) | `dotfiles` CLI — one command to link/status/install all configs |

## Theme

[Aura Dark](https://github.com/daltonmenezes/aura-theme) across terminal and editor.

## Setup

```bash
git clone https://github.com/aBER0724/dotfiles.git ~/dotfiles
ln -sf ~/dotfiles/bin/dotfiles ~/.local/bin/dotfiles

dotfiles status    # show link state for every synced entry
dotfiles link      # create missing links; backup+replace conflicting files
dotfiles deps      # install zsh/herdr runtime deps (plugins, p10k, ...)
dotfiles install   # link + install group deps + pi bootstrap hint
dotfiles install wm  # link niri+nbshell; installs only under ~/.local (never sudo)
```

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

## herdr

Config in `~/.config/herdr/`, synced from [herdr/](herdr/README.md).

- **Synced**: `config.toml` (theme, keybindings), `plugins.txt` (plugin sources)
- **Not synced**: installed plugins, logs, session state
- **Plugins**: installed by source in `plugins.txt`; on a new device one command installs them all:

  `brew install herdr` + `brew install macintacos/tap/herdr-scratch`(scratch 插件的二进制;Linux 同样支持 brew,或 `curl -fsSL https://herdr.dev/install.sh | sh`),然后 `dotfiles install` 会链接配置并重装所有插件。插件带构建步骤的需要工具链(如 go),装好再跑 `bash ~/dotfiles/herdr/install-plugins.sh`