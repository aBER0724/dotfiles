# System-specific one-command setup design

## Goal

Extend the existing `dotfiles` CLI with system presets that install and configure the repository's primary stack on macOS and Arch Linux:

```bash
dotfiles setup macos
dotfiles setup arch
dotfiles setup auto
```

The command installs required software, creates the appropriate configuration links, and runs the existing user-level installers and plugin installers. It does not enable services, change the login shell, launch GUI applications, or create API credentials.

## Command behavior

### `dotfiles setup auto`

Detect the host and dispatch to the explicit preset:

- `uname -s = Darwin` selects `macos`.
- Linux with `ID=arch` or an `ID_LIKE` containing `arch` in `/etc/os-release` selects `arch`.
- Other systems fail with a clear unsupported-system message and list the explicit supported presets.

### Explicit preset validation

- `setup macos` refuses to run unless `uname -s` is `Darwin`.
- `setup arch` refuses to run unless the host is Arch or Arch-derived and `pacman` exists.
- Unknown preset names fail without changing the machine.

This prevents accidentally applying a foreign package/config preset.

## Declarative presets

Add a table near `GROUP_TABLE` mapping each preset to managed entries. Presets contain only the primary configuration stack, not rollback configurations.

### Shared primary entries

- `dotfiles-cli`
- `zsh`
- `nvim`
- `fastfetch`
- `pi`
- `herdr`

### macOS additions

- `aerospace`
- `kitty`

The existing platform-specific Kitty include mechanism remains responsible for choosing `platform-macos.conf`; linking the Kitty group is safe because both platform files are configuration assets rather than active processes.

### Arch additions

- `niri`
- `nbshell`
- `kitty`

Waybar and Clavis are excluded because they are rollback paths. Kaku is excluded because Kitty is the primary terminal and Kaku has no stable package-manager mapping in the current repository.

## Package bootstrap and installation

### macOS

1. Check for Homebrew.
2. If absent, run the official non-interactive Homebrew installer from `https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh`.
3. Initialize Homebrew in the current process using the standard Apple Silicon or Intel prefix detected after installation.
4. Install shared prerequisites before existing config-owned software:
   - `git`
   - `zsh`
   - `node`
   - `go`
5. Reuse the current software table and `run_software_install` for AeroSpace, Neovim, Kitty, Fastfetch, pi, herdr, and herdr-scratch.

Homebrew installation is the only new remote bootstrap. The URL is fixed and printed before execution.

### Arch Linux

1. Require `pacman` and `sudo`.
2. Install shared prerequisites in one transaction:
   - `git`
   - `curl`
   - `zsh`
   - `nodejs`
   - `npm`
   - `go`
   - `base-devel`
3. Install the preset-owned packages through the existing software table.
4. Include the complete package list from `nbshell/packages.arch.txt` in the same dependency flow so optional synchronized features are available in a one-command setup.
5. Install herdr through its official user-local installer when it remains unavailable after system packages. Install `herdr-scratch` only when a supported package source exists; otherwise report it as an optional manual follow-up without failing the whole preset.

Pacman operations use `sudo pacman -S --needed` and remain idempotent.

## Configuration and runtime installers

After package installation, the setup command invokes the existing installation path with the preset's expanded managed entries. This preserves current behavior:

- Real-file conflicts are moved to one timestamped backup directory.
- Correct links are skipped.
- Zsh plugins and Powerlevel10k are installed.
- herdr plugins are installed from the pinned inventory.
- nbshell is installed under `~/.local` and its generated integrations are configured.
- The pi fallback theme and API-key hint are produced.

The setup implementation should avoid running package installation twice. Refactor the current install flow into two explicit phases if necessary:

1. package/software installation;
2. linking and config-specific installers.

`dotfiles install` and `dotfiles deps` must retain their current public behavior.

## Actions deliberately left manual

The command prints, but does not execute, the following host-policy changes:

### macOS

- Start AeroSpace or grant Accessibility permissions.
- Change the default login shell.

### Arch Linux

```bash
systemctl --user enable --now nbshell.service
sudo systemctl enable --now tuned.service
```

It also does not configure the pi API key or enable login/startup items.

## Error handling

- Unsupported platform or missing required package manager: fail before linking files.
- Homebrew bootstrap failure: stop and show how to rerun the installer manually.
- Required package installation failure: stop; rerunning is safe because package and link operations are idempotent.
- Optional herdr-scratch installation failure on Arch: warn and continue.
- Existing config conflicts: use the CLI's current backup-and-replace behavior.
- User-local plugin/install script failure: propagate the failure so setup is not reported complete.

## CLI output

Each stage receives a visible heading:

```text
== detect system ==
== bootstrap package manager ==
== install base packages ==
== install config software ==
== link configs ==
== install config runtimes ==
== manual follow-up ==
```

The final output lists only remaining manual actions. It must not claim full success if a required stage failed.

## Testing

Add shell-level tests using temporary homes and stub executables rather than invoking real package managers.

Cover:

1. `setup auto` selects macOS from a stubbed `uname`.
2. `setup auto` selects Arch from a fixture `os-release`.
3. Explicit preset/platform mismatch fails before package or link commands.
4. macOS without `brew` invokes the fixed bootstrap URL, initializes the detected prefix, and proceeds.
5. macOS with `brew` skips bootstrap.
6. Arch batches base and config packages with `sudo pacman -S --needed`.
7. Correct preset entries are linked; Waybar, Clavis, and Kaku are excluded.
8. Existing links and installed commands are skipped.
9. Required-stage failure returns non-zero.
10. Manual service commands are printed but never executed.
11. Existing `list`, `status`, `link`, `install`, and `deps` behavior remains covered by smoke tests.

The production script remains compatible with macOS Bash 3.2.
