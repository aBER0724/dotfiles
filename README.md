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
```
