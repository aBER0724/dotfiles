# pi-agent

[pi coding agent](https://pi.dev) config synced across devices.

## What's synced

| File | Purpose |
|------|---------|
| `settings.json` | Plugin list (`packages`), theme, default provider/model |
| `models.json` | Custom provider definitions (e.g. `new-api`) — no secrets |
| `extensions/` | Custom extension configs (pi-autoresearch, pi-rtk-optimizer, herdr) |

## Why this works

`settings.json`'s `packages` array stores the *sources* of installed plugins
(e.g. `npm:pi-subagents`). pi re-installs any missing package on startup, so the
`~/.pi/agent/npm/` and `~/.pi/agent/git/` caches are per-device and **not**
synced.

## What's intentionally NOT synced

- `auth.json` — API keys, never synced. All providers are third-party key-based (no OAuth login); set the key per device.
- `models-store.json`, `sessions/`, `state/`, `fff/` — machine-local.
- `npm/`, `git/` — package install caches, rebuilt automatically.

## New device setup

```bash
# after cloning and running the root README symlinks:
ln -sf ~/dotfiles/pi-agent/settings.json ~/.pi/agent/settings.json
ln -sf ~/dotfiles/pi-agent/models.json  ~/.pi/agent/models.json
ln -sf ~/dotfiles/pi-agent/extensions ~/.pi/agent/extensions

# ensure dirs exist before first pi run
mkdir -p ~/.pi/agent

# set API key once per device (no login — providers are key-based):
printf '{"new-api": "sk-..."}' > ~/.pi/agent/auth.json
# or export $NEW_API_KEY and reference it as apiKey in models.json

# then pick default model once per device
pi
```

> Note: `defaultProvider`/`defaultModel` from settings.json apply only if the
> provider exists on the device (models.json handles custom ones). Provider
> API keys always come from the local `auth.json`.