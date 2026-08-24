# dotfiles

Personal configuration files.

## Contents

| Config | Description |
|--------|-------------|
| [aerospace](/aerospace) | AeroSpace tiling window manager |
| [kaku](/kaku) | Terminal (WezTerm-based) |
| [nvim](/nvim) | Neovim (LazyVim) |
| [fastfetch](/fastfetch) | System info |
| [zsh](/zsh) | Zsh config (zshrc, zprofile, zshenv, p10k) |
| [pi-agent](/pi-agent) | pi coding agent — syncs settings, models, extensions; API keys stay per-device |
| [herdr](/herdr) | Terminal workspace manager — syncs config.toml + plugin inventory |

## Theme

[Aura Dark](https://github.com/daltonmenezes/aura-theme) across terminal and editor.

## Setup

```bash
git clone https://github.com/aBER0724/dotfiles.git ~/dotfiles

ln -sf ~/dotfiles/aerospace/aerospace.toml ~/.aerospace.toml

ln -sf ~/dotfiles/zsh/zshrc ~/.zshrc
ln -sf ~/dotfiles/zsh/zshenv ~/.zshenv
ln -sf ~/dotfiles/zsh/zprofile ~/.zprofile
ln -sf ~/dotfiles/zsh/shinit ~/.shinit
ln -sf ~/dotfiles/zsh/p10k.zsh ~/.p10k.zsh

ln -sf ~/dotfiles/nvim ~/.config/nvim
ln -sf ~/dotfiles/kaku ~/.config/kaku
ln -sf ~/dotfiles/fastfetch ~/.config/fastfetch

ln -sf ~/dotfiles/pi-agent/settings.json ~/.pi/agent/settings.json
ln -sf ~/dotfiles/pi-agent/models.json  ~/.pi/agent/models.json
ln -sf ~/dotfiles/pi-agent/extensions ~/.pi/agent/extensions

ln -sf ~/dotfiles/herdr/config.toml ~/.config/herdr/config.toml
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

  `brew install herdr` + `brew install macintacos/tap/herdr-scratch`(scratch 插件的二进制) → `ln -sf ~/dotfiles/herdr/config.toml ~/.config/herdr/config.toml` → `bash ~/dotfiles/herdr/install-plugins.sh`