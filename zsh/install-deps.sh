#!/bin/bash
# Install zsh runtime dependencies that .zshrc expects but are NOT part of
# dotfiles sync (they are git clones / package installs, not config files).
#
#   autosuggestions, syntax-highlighting, completions, zsh-z -> $ZSH_CUSTOM/plugins/
#     (same 4 plugins Kaku bundles; zshrc loads them on any platform)
#   powerlevel10k                          -> $ZSH_CUSTOM/themes/
#   thefuck                                -> package manager (optional)
#   nvm                                    -> standalone install (optional)
#
# Idempotent: already-installed items are skipped. Run on a new machine
# BEFORE sourcing .zshrc, or after; either works since .zshrc is defensive.
# Usage: bash ~/dotfiles/zsh/install-deps.sh
set -euo pipefail

DOTFILES="${DOTFILES_DIR:-$HOME/dotfiles}"
ZSH_CUSTOM="${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}"


if [ ! -r "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
  echo "== oh-my-zsh =="
  if [ -e "$HOME/.oh-my-zsh" ]; then
    echo "error   $HOME/.oh-my-zsh exists but oh-my-zsh.sh is missing" >&2
    echo "Move or remove that incomplete directory, then rerun this installer." >&2
    exit 1
  fi
  echo "install ohmyzsh/ohmyzsh -> $HOME/.oh-my-zsh"
  git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi
mkdir -p "$ZSH_CUSTOM/plugins" "$ZSH_CUSTOM/themes"

install_plugin() { # $1=owner/repo, $2=dest dir name
  local repo="$1" dest="$2" dir
  dir="$ZSH_CUSTOM/$dest"
  if [ -d "$dir/.git" ]; then
    echo "ok      $repo -> $dir (already installed)"
  else
    echo "install $repo -> $dir"
    git clone --depth 1 "https://github.com/$repo.git" "$dir"
  fi
}

echo "== oh-my-zsh plugins =="
install_plugin zsh-users/zsh-autosuggestions     plugins/zsh-autosuggestions
install_plugin zsh-users/zsh-syntax-highlighting plugins/zsh-syntax-highlighting
install_plugin zsh-users/zsh-completions        plugins/zsh-completions
install_plugin agkozak/zsh-z                    plugins/zsh-z
echo "== powerlevel10k =="
if [ -d "$ZSH_CUSTOM/themes/powerlevel10k/.git" ]; then
  echo "ok      powerlevel10k (already installed)"
else
  echo "install powerlevel10k"
  git clone --depth 1 https://github.com/romkatv/powerlevel10k.git \
    "$ZSH_CUSTOM/themes/powerlevel10k"
fi

echo "== thefuck (optional) =="
if command -v thefuck >/dev/null 2>&1; then
  echo "ok      thefuck already available"
elif command -v brew >/dev/null 2>&1; then
  echo "install thefuck via brew (interactive — skipping; run: brew install thefuck)"
elif command -v apt-get >/dev/null 2>&1; then
  echo "run:    sudo apt install thefuck"
elif command -v dnf >/dev/null 2>&1; then
  echo "run:    sudo dnf install thefuck"
else
  echo "hint:   pip install thefuck  (no package manager detected)"
fi

echo "== nvm (optional) =="
if [ -s "$HOME/.nvm/nvm.sh" ] || [ -s /opt/homebrew/opt/nvm/nvm.sh ]; then
  echo "ok      nvm already available"
else
  echo "run:    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"
fi

echo
echo "done. Re-source: exec zsh"