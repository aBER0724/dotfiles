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
| [pi-agent](/pi-agent) | pi coding agent (settings, models, extensions) |
| [herdr](/herdr) | Terminal workspace manager (config, plugins) |

## Theme

[Aura Dark](https://github.com/daltonmenezes/aura-theme) across terminal and editor.

## Setup

```bash
git clone https://github.com/aBER0724/dotfiles.git ~/dotfiles

# AeroSpace
ln -sf ~/dotfiles/aerospace/aerospace.toml ~/.aerospace.toml

# Zsh
ln -sf ~/dotfiles/zsh/zshrc ~/.zshrc
ln -sf ~/dotfiles/zsh/zshenv ~/.zshenv
ln -sf ~/dotfiles/zsh/zprofile ~/.zprofile
ln -sf ~/dotfiles/zsh/shinit ~/.shinit
ln -sf ~/dotfiles/zsh/p10k.zsh ~/.p10k.zsh


# XDG configs
ln -sf ~/dotfiles/nvim ~/.config/nvim
ln -sf ~/dotfiles/kaku ~/.config/kaku
ln -sf ~/dotfiles/fastfetch ~/.config/fastfetch

# Pi
ln -sf ~/dotfiles/pi-agent/settings.json ~/.pi/agent/settings.json
ln -sf ~/dotfiles/pi-agent/models.json  ~/.pi/agent/models.json
ln -sf ~/dotfiles/pi-agent/extensions ~/.pi/agent/extensions

# Herdr
ln -sf ~/dotfiles/herdr/config.toml ~/.config/herdr/config.toml
```

---

## Pi coding agent

[pi](https://pi.dev) is a terminal coding harness. Its config lives in `~/.pi/agent/`,
synced from [`pi-agent/`](pi-agent/).

### What's synced

- `settings.json` — plugin list (`packages`), theme, default provider/model
- `models.json` — custom provider definitions (`new-api`), no secrets
- `extensions/` — custom extension configs

### What's NOT synced

- `auth.json` — API credentials; run `/login` + `/model` per device
- `models-store.json`, `sessions/`, `state/`, `fff/` — machine-local
- `npm/`, `git/` — package install caches, rebuilt automatically

### How plugin sync works

`settings.json`'s `packages` array stores *sources* (e.g. `npm:pi-subagents`),
not the plugins themselves. Pi re-installs any missing package on startup, so
the `npm/ git/` caches are per-device and never synced.

### Adding a new pi package

```bash
pi install npm:some-package   # writes to settings.json → picked up by git
git -C ~/dotfiles commit -m "add pi plugin" -a
```

### New device

```bash
mkdir -p ~/.pi/agent
ln -sf ~/dotfiles/pi-agent/settings.json ~/.pi/agent/settings.json
ln -sf ~/dotfiles/pi-agent/models.json  ~/.pi/agent/models.json
ln -sf ~/dotfiles/pi-agent/extensions ~/.pi/agent/extensions
pi          # start: auto-installs all packages on first launch
/login      # once per device: API key (stored in local auth.json)
/model      # pick default model (defaultProvider from settings.json)
```

## Herdr

[herdr](https://herdr.dev) is a terminal workspace manager for AI coding agents,
config synced from [`herdr/`](herdr/).

### What's synced

- `config.toml` — theme, keybindings, UI settings
- `plugins.txt` — plugin inventory (GitHub owner/repo + pinned ref)
- `scratch/herdr-plugin.toml` — local `user.scratch` plugin manifest

### What's NOT synced

- `plugins.json`, `plugins/` — install state + downloaded code, rebuilt by setup
- `*.log`, `*.sock`, `.plugins.lock` — runtime artifacts
- `session.json`, `release-notes.json` — session/update state
- `config.toml.hunkdiff-backup` — plugin-owned backup

### How plugins work

herdr's `plugins.json` records absolute install paths, so it can't be synced.
`plugins.txt` instead captures the *sources* (owner/repo + pinned ref), enough to
reinstall every plugin at the exact same version on a new device.

### Installing a herdr plugin

```bash
herdr plugin install owner/repo --ref v1.2.3
# regenerate herdr/plugins.txt from installed state, then commit:
bash ~/dotfiles/herdr/gen-plugins.sh
git -C ~/dotfiles commit -am "add herdr plugin"
```

### New device

```bash
brew install herdr herdr-scratch
ln -sf ~/dotfiles/herdr/config.toml ~/.config/herdr/config.toml
while IFS='|' read -r id kind cmd; do
  [ "$kind" = "github" ] && eval "$cmd -y"
done < ~/dotfiles/herdr/plugins.txt
ln -s ~/dotfiles/herdr/scratch ~/.local/share/herdr-scratch
herdr plugin link ~/.local/share/herdr-scratch
```
