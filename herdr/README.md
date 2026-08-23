# herdr

[herdr](https://herdr.dev) terminal workspace manager for AI coding agents.

## What's synced

| File | Purpose |
|------|---------|
| `config.toml` | Theme, keybindings, UI settings |
| `plugins.txt` | Plugin inventory (owner/repo + pinned ref) |
| `scratch/herdr-plugin.toml` | Local `user.scratch` plugin manifest |

## Why plugins.json is NOT synced

herdr's `plugins.json` records absolute install paths
(e.g. `/Users/aber/.config/herdr/plugins/...`) that are machine-specific.
Instead, `plugins.txt` captures the *sources* (GitHub owner/repo + pinned ref),
which is enough to reinstall everything on a new device.

## What's intentionally NOT synced

- `plugins.json`, `plugins/` — install state + downloaded code, rebuilt by setup
- `*.log`, `*.sock`, `.plugins.lock` — runtime artifacts
- `session.json`, `release-notes.json` — session/update state
- `config.toml.hunkdiff-backup` — plugin-owned backup

## New device setup

```bash
# 1. required binaries (Homebrew)
brew install herdr herdr-scratch

# 2. link config
ln -sf ~/dotfiles/herdr/config.toml ~/.config/herdr/config.toml

# 3. install plugins from inventory
while IFS='|' read -r id kind cmd; do
  [ "$kind" = "github" ] && eval "$cmd -y"
done < ~/dotfiles/herdr/plugins.txt

# 4. link local scratch plugin
ln -s ~/dotfiles/herdr/scratch ~/.local/share/herdr-scratch
herdr plugin link ~/.local/share/herdr-scratch
```