# dotfiles

Personal configuration files.

## Contents

| Config | Description |
|--------|-------------|
| [kaku](/.config/kaku) | Terminal (WezTerm-based) |
| [nvim](/.config/nvim) | Neovim (LazyVim) |
| [fastfetch](/.config/fastfetch) | System info |

## Theme

[Aura Dark](https://github.com/daltonmenezes/aura-theme) across terminal and editor.

## Setup

```bash
git clone https://github.com/aBER0724/dotfiles.git ~/dotfiles

# Symlink configs
ln -sf ~/dotfiles/.config/kaku ~/.config/kaku
ln -sf ~/dotfiles/.config/nvim ~/.config/nvim
ln -sf ~/dotfiles/.config/fastfetch ~/.config/fastfetch
```
