# mise toolchains

Each profile gets its own mise config; `dotfiles setup` links the matching file
to `~/.config/mise/config.toml` (the `mise-config` link entry resolves the
`@profile/` source via `mise_profile` in `bin/dotfiles`).

| File | Used by | Notes |
|------|---------|-------|
| `macos.toml` | `setup macos` | GUI apps (AeroSpace, Kitty, herdr-scratch) stay in Homebrew casks; zsh/tmux stay formulae. Also owns the general CLI layer (fzf, fd, jq, zoxide, starship, delta, btop, gh, glab, uv, bun, yt-dlp, rclone, tree, 7zip), Java (temurin-21 replaces openjdk@21 + temurin casks), and npm AI CLIs — only pi + claude code are kept, plus trellis and wecom-cli. |
| `linux-desktop.toml` | `setup linux omarchy` / `linux niri` | Desktop stack (niri, quickshell, fcitx5, kitty, waybar) stays in pacman. |
| `linux-server.toml` | `setup linux server` | `herdr` installs from its official release binary instead of the `ubi:` spec; `ubi` is disabled by default on mise ≥2025.10 so flip `settings.ubi` or vendor the binary. |

Edit a file to change tool versions, then run `mise install` (or
`dotfiles deps mise`) to converge. Per-profile divergence is intentional:
the same job may map to a different tool on another OS.

Notes:
- `mise install <name>` pins new versions into the linked TOML, so `dotfiles
  deps` stays reproducible across machines.
- Deliberately not migrated (kept in Homebrew): ffmpeg/imagemagick/graphviz
  library trees, cmake/automake build chain, mas/pinentry-mac/
  switchaudio-osx and other mac-specific helpers, taps (wechattweak,
  cfstc, sunshine, mole, x-cmd), services (ollama, wireguard-go,
  blackhole, watchman), zsh-syntax-highlighting (sourced by brew path
  from zshrc), nvm (superseded by mise node).
- npm globals intentionally dropped: codex, gemini-cli,
  claude-code-router, happy, cloudbase-cli, trellis, wecom-cli,
  wechat-cli, immich-cli, pocketjs-cli, pake-cli, puppeteer-core,
  react-native-cli. Kept npm globals: pi, claude-code, ccline,
  gitee-cli, happy-coder (separate package from `happy`), wrangler,
  pnpm, yarn.
