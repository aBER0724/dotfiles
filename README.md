# dotfiles

Personal configuration files.

## Contents

| Config | Description |
|--------|-------------|
| [aerospace](/aerospace) | AeroSpace tiling window manager (macOS) |
| [niri](/niri) | Niri scrollable-tiling compositor — AeroSpace-style bindings, scripts/ |
| [waybar](/waybar) | Waybar for niri (niri/workspaces, Catppuccin Mocha) |
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