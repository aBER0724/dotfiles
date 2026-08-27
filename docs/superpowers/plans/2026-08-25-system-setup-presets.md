# System Setup Presets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `dotfiles setup macos|arch|auto` to install and configure the repository's primary stack safely and idempotently on macOS and Arch Linux.

**Architecture:** Keep `bin/dotfiles` as the Bash 3.2-compatible production CLI, but add explicit preset detection, validation, package bootstrap, and staged configuration functions. Add a self-contained shell test harness in `tests/dotfiles_setup_test.sh` that runs the CLI with temporary homes, fixture OS metadata, and stub package-manager commands, so no test changes the real host.

**Tech Stack:** Bash 3.2-compatible shell, Homebrew, pacman, npm, Git, temporary-directory shell tests.

## Global Constraints

- Support exactly `dotfiles setup macos`, `dotfiles setup arch`, and `dotfiles setup auto`.
- macOS and Arch presets install only the primary stack; Waybar, Clavis, and Kaku remain excluded.
- macOS automatically bootstraps Homebrew from `https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh` when `brew` is absent.
- Arch package operations use `sudo pacman -S --needed`.
- Setup installs packages, creates links, and runs existing user-level installers, but does not enable services, change the login shell, launch GUI applications, or create API credentials.
- Existing `list`, `status`, `link`, `install`, and `deps` behavior must remain intact.
- Correct links and installed software must be skipped; rerunning setup must be safe.
- Production code must remain compatible with macOS Bash 3.2.
- Tests must never invoke a real package manager, `sudo`, `curl`, system service manager, or destructive cleanup outside a test-owned temporary root.

---

## File map

- Modify `bin/dotfiles`: preset declarations, host detection, package-manager bootstrap, staged setup orchestration, and CLI help/dispatch.
- Create `tests/dotfiles_setup_test.sh`: isolated integration-style tests with stubs and assertions for setup plus regression smoke tests for existing commands.
- Modify `README.md`: concise public setup examples and manual follow-up commands.
- Modify `bin/README.md`: full command contract, preset contents, safety boundaries, and platform behavior.

### Task 1: Add the isolated shell test harness and preset-selection tests

**Files:**
- Create: `tests/dotfiles_setup_test.sh`
- Test: `tests/dotfiles_setup_test.sh`

**Interfaces:**
- Consumes: `bin/dotfiles` as the CLI under test.
- Produces: test helpers `new_case`, `stub_command`, `run_cli`, `assert_contains`, `assert_not_contains`, `assert_status`; environment seams `DOTFILES_UNAME`, `DOTFILES_OS_RELEASE`, and `DOTFILES_HOMEBREW_INSTALL_URL` expected from later production tasks.

- [ ] **Step 1: Create the harness and failing auto-detection tests**

Create `tests/dotfiles_setup_test.sh` with strict cleanup restricted to one `mktemp -d` root:

```bash
#!/bin/bash
set -eu

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-setup.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT HUP INT TERM
PASS=0
FAIL=0

new_case() {
  CASE_ROOT="$TEST_ROOT/$1"
  HOME="$CASE_ROOT/home"
  STUB_BIN="$CASE_ROOT/bin"
  LOG="$CASE_ROOT/commands.log"
  mkdir -p "$HOME" "$STUB_BIN"
  : > "$LOG"
  export HOME STUB_BIN LOG
}

stub_command() {
  name="$1"
  body="$2"
  printf '#!/bin/sh\n%s\n' "$body" > "$STUB_BIN/$name"
  chmod +x "$STUB_BIN/$name"
}

run_cli() {
  OUTPUT="$CASE_ROOT/output"
  STATUS=0
  PATH="$STUB_BIN:/usr/bin:/bin" \
    DOTFILES_DIR="$REPO" \
    bash "$REPO/bin/dotfiles" "$@" >"$OUTPUT" 2>&1 || STATUS=$?
}

assert_status() {
  expected="$1"
  [ "$STATUS" -eq "$expected" ] || {
    echo "FAIL: expected status $expected, got $STATUS" >&2
    cat "$OUTPUT" >&2
    return 1
  }
}

assert_contains() {
  needle="$1"
  grep -F "$needle" "$OUTPUT" >/dev/null || {
    echo "FAIL: missing output: $needle" >&2
    cat "$OUTPUT" >&2
    return 1
  }
}

assert_not_contains() {
  needle="$1"
  if grep -F "$needle" "$OUTPUT" >/dev/null; then
    echo "FAIL: unexpected output: $needle" >&2
    cat "$OUTPUT" >&2
    return 1
  fi
}

run_test() {
  name="$1"
  shift
  if "$@"; then PASS=$((PASS + 1)); echo "ok - $name"
  else FAIL=$((FAIL + 1)); echo "not ok - $name"
  fi
}

test_auto_detects_macos() {
  new_case auto-macos
  DOTFILES_UNAME=Darwin run_cli setup auto
  assert_status 0 && assert_contains "preset  macos"
}

test_auto_detects_arch() {
  new_case auto-arch
  cat > "$CASE_ROOT/os-release" <<'OS'
ID=arch
NAME="Arch Linux"
OS
  DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup auto
  assert_status 0 && assert_contains "preset  arch"
}

run_test "auto detects macOS" test_auto_detects_macos
run_test "auto detects Arch" test_auto_detects_arch

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

The tests intentionally expect environment seams so host detection is deterministic without stubbing the global `uname` binary.

- [ ] **Step 2: Run the tests and verify they fail**

Run:

```bash
bash tests/dotfiles_setup_test.sh
```

Expected: both tests fail because `setup` is not yet a recognized command; final summary is `0 passed, 2 failed` and exit status is non-zero.

- [ ] **Step 3: Commit the failing tests**

```bash
git add tests/dotfiles_setup_test.sh
git commit -m "test(dotfiles): cover system preset detection"
```

### Task 2: Implement preset declarations, host detection, and platform guards

**Files:**
- Modify: `bin/dotfiles` near `GROUP_TABLE`, helper functions, and command dispatch.
- Modify: `tests/dotfiles_setup_test.sh`
- Test: `tests/dotfiles_setup_test.sh`

**Interfaces:**
- Consumes: `DOTFILES_UNAME` override and `DOTFILES_OS_RELEASE` fixture path from the test harness.
- Produces: `PRESET_TABLE`, `detect_system() -> stdout macos|arch`, `validate_system(preset)`, `preset_entries(preset) -> stdout expanded names`, and initial `cmd_setup(preset)` orchestration.

- [ ] **Step 1: Add failing tests for explicit mismatch and unknown presets**

Append these tests before the `run_test` calls and register them:

```bash
test_macos_rejects_linux() {
  new_case reject-macos
  DOTFILES_UNAME=Linux run_cli setup macos
  assert_status 1 && assert_contains "setup macos requires macOS"
  [ ! -s "$LOG" ]
}

test_arch_rejects_macos() {
  new_case reject-arch
  DOTFILES_UNAME=Darwin run_cli setup arch
  assert_status 1 && assert_contains "setup arch requires Arch Linux"
  [ ! -s "$LOG" ]
}

test_unknown_preset_fails() {
  new_case unknown
  DOTFILES_UNAME=Darwin run_cli setup debian
  assert_status 1 && assert_contains "unknown setup preset 'debian'"
}
```

Register:

```bash
run_test "macOS preset rejects Linux" test_macos_rejects_linux
run_test "Arch preset rejects macOS" test_arch_rejects_macos
run_test "unknown preset fails" test_unknown_preset_fails
```

- [ ] **Step 2: Run tests and verify the new cases fail**

Run: `bash tests/dotfiles_setup_test.sh`

Expected: non-zero exit; mismatch/unknown-preset expectations are absent.

- [ ] **Step 3: Add the preset table and detection helpers**

Add after `GROUP_TABLE`:

```bash
PRESET_TABLE=(
  "macos|dotfiles-cli zsh nvim fastfetch pi herdr aerospace kitty"
  "arch|dotfiles-cli zsh nvim fastfetch pi herdr niri nbshell kitty"
)
```

Add helpers after `expand_groups`:

```bash
host_uname() {
  if [ -n "${DOTFILES_UNAME:-}" ]; then
    printf '%s\n' "$DOTFILES_UNAME"
  else
    uname -s
  fi
}

is_arch_host() {
  local os_release="${DOTFILES_OS_RELEASE:-/etc/os-release}" id="" id_like=""
  [ "$(host_uname)" = "Linux" ] || return 1
  [ -r "$os_release" ] || return 1
  id="$(sed -n 's/^ID=//p' "$os_release" | head -n 1 | tr -d '\"')"
  id_like="$(sed -n 's/^ID_LIKE=//p' "$os_release" | head -n 1 | tr -d '\"')"
  [ "$id" = "arch" ] && return 0
  case " $id_like " in *" arch "*) return 0 ;; esac
  return 1
}

detect_system() {
  if [ "$(host_uname)" = "Darwin" ]; then
    echo macos
  elif is_arch_host; then
    echo arch
  else
    echo "dotfiles: unsupported system; supported presets: macos arch" >&2
    return 1
  fi
}

validate_system() {
  case "$1" in
    macos)
      [ "$(host_uname)" = "Darwin" ] || {
        echo "dotfiles: setup macos requires macOS" >&2
        return 1
      }
      ;;
    arch)
      is_arch_host || {
        echo "dotfiles: setup arch requires Arch Linux" >&2
        return 1
      }
      ;;
    *)
      echo "dotfiles: unknown setup preset '$1' (supported: auto macos arch)" >&2
      return 1
      ;;
  esac
}

preset_entries() {
  local preset="$1" row
  for row in "${PRESET_TABLE[@]}"; do
    if [ "${row%%|*}" = "$preset" ]; then
      expand_groups "${row#*|}"
      return 0
    fi
  done
  return 1
}
```

Add the initial setup command:

```bash
cmd_setup() {
  local preset="${1:-auto}" wanted
  echo "== detect system =="
  [ "$preset" = auto ] && preset="$(detect_system)"
  validate_system "$preset"
  wanted="$(preset_entries "$preset")"
  echo "preset  $preset"
  printf 'entries %s\n' "$wanted"
}
```

Update dispatch and usage:

```bash
setup) shift; cmd_setup "${1:-auto}" ;;
```

and:

```bash
echo "Usage: dotfiles {list|status|link|install|deps|setup} [name...]"
echo "  setup [auto|macos|arch]  install and configure the primary system preset"
```

- [ ] **Step 4: Run syntax and tests**

Run:

```bash
bash -n bin/dotfiles
bash tests/dotfiles_setup_test.sh
```

Expected: syntax exits 0; all five tests pass.

- [ ] **Step 5: Commit**

```bash
git add bin/dotfiles tests/dotfiles_setup_test.sh
git commit -m "feat(dotfiles): detect system setup presets"
```

### Task 3: Implement macOS Homebrew bootstrap and base packages

**Files:**
- Modify: `bin/dotfiles`
- Modify: `tests/dotfiles_setup_test.sh`
- Test: `tests/dotfiles_setup_test.sh`

**Interfaces:**
- Consumes: validated `macos` preset; optional `DOTFILES_HOMEBREW_INSTALL_URL` fixed-url test seam; stubbed `curl`, `bash`, and `brew` commands.
- Produces: `ensure_homebrew()`, `load_homebrew()`, and `install_base_packages(macos)`.

- [ ] **Step 1: Add failing tests for bootstrap and existing Homebrew**

Add a reusable command logger:

```bash
stub_logger() {
  name="$1"
  stub_command "$name" 'printf "%s %s\\n" "$(basename "$0")" "$*" >> "$LOG"'
}
```

Add tests:

```bash
test_macos_bootstraps_homebrew() {
  new_case macos-bootstrap
  stub_command curl 'printf "curl %s\\n" "$*" >> "$LOG"; printf "#!/bin/sh\\nexit 0\\n"'
  stub_command brew 'printf "brew %s\\n" "$*" >> "$LOG"'
  DOTFILES_UNAME=Darwin DOTFILES_FORCE_NO_BREW=1 run_cli setup macos
  assert_status 0 && grep -F "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" "$LOG" >/dev/null
}

test_macos_skips_homebrew_bootstrap() {
  new_case macos-existing-brew
  stub_logger brew
  stub_command curl 'echo unexpected-curl >> "$LOG"; exit 99'
  DOTFILES_UNAME=Darwin run_cli setup macos
  assert_status 0 && ! grep -F "unexpected-curl" "$LOG" >/dev/null
}
```

Use `DOTFILES_FORCE_NO_BREW=1` only as a test seam to force the absent branch while retaining a stub `brew` for post-bootstrap calls.

- [ ] **Step 2: Run tests and verify the new cases fail**

Run: `bash tests/dotfiles_setup_test.sh`

Expected: bootstrap URL is not logged and base package installation is absent.

- [ ] **Step 3: Add Homebrew bootstrap helpers**

Add constants near `PI_DEFAULT_PROVIDER`:

```bash
HOMEBREW_INSTALL_URL="${DOTFILES_HOMEBREW_INSTALL_URL:-https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh}"
MACOS_BASE_PACKAGES="git zsh node go"
ARCH_BASE_PACKAGES="git curl zsh nodejs npm go base-devel"
```

Add:

```bash
load_homebrew() {
  if command -v brew >/dev/null 2>&1; then return 0; fi
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    echo "dotfiles: Homebrew installed but brew is not available in this shell" >&2
    return 1
  fi
}

ensure_homebrew() {
  if [ "${DOTFILES_FORCE_NO_BREW:-0}" != 1 ] && command -v brew >/dev/null 2>&1; then
    return 0
  fi
  command -v curl >/dev/null 2>&1 || {
    echo "dotfiles: curl is required to install Homebrew" >&2
    return 1
  }
  echo "install Homebrew from $HOMEBREW_INSTALL_URL"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "$HOMEBREW_INSTALL_URL")" || {
    echo "dotfiles: Homebrew bootstrap failed; rerun the installer from $HOMEBREW_INSTALL_URL" >&2
    return 1
  }
  [ "${DOTFILES_FORCE_NO_BREW:-0}" = 1 ] && command -v brew >/dev/null 2>&1 && return 0
  load_homebrew
}

install_base_packages() {
  case "$1" in
    macos) brew install $MACOS_BASE_PACKAGES ;;
    arch) sudo pacman -S --needed $ARCH_BASE_PACKAGES ;;
  esac
}
```

`/bin/bash` is deliberate for the official installer. In the test, introduce `DOTFILES_BASH_BIN` if direct `/bin/bash` prevents isolation:

```bash
BOOTSTRAP_BASH="${DOTFILES_BASH_BIN:-/bin/bash}"
```

and call `"$BOOTSTRAP_BASH" -c ...`; set `DOTFILES_BASH_BIN="$STUB_BIN/bash"` in the bootstrap test.

- [ ] **Step 4: Integrate macOS stages into `cmd_setup`**

After validation and preset output:

```bash
if [ "$preset" = macos ]; then
  echo "== bootstrap package manager =="
  ensure_homebrew
fi
echo "== install base packages =="
install_base_packages "$preset"
```

Do not link configurations yet.

- [ ] **Step 5: Run syntax and tests**

Run:

```bash
bash -n bin/dotfiles
bash tests/dotfiles_setup_test.sh
```

Expected: all tests pass; the bootstrap test records the fixed URL; existing-brew test records no curl call.

- [ ] **Step 6: Commit**

```bash
git add bin/dotfiles tests/dotfiles_setup_test.sh
git commit -m "feat(dotfiles): bootstrap macOS package tooling"
```

### Task 4: Implement Arch package aggregation and package-stage failures

**Files:**
- Modify: `bin/dotfiles`
- Modify: `tests/dotfiles_setup_test.sh`
- Test: `tests/dotfiles_setup_test.sh`

**Interfaces:**
- Consumes: `ARCH_BASE_PACKAGES`, `nbshell/packages.arch.txt`, `SOFTWARE_TABLE`, validated Arch host, stubbed `sudo`, `pacman`, and software commands.
- Produces: `read_arch_package_file(path) -> stdout package string`, `install_arch_setup_packages(wanted)`, and a setup package stage that stops before linking on failure.

- [ ] **Step 1: Add failing Arch package and failure-propagation tests**

Add:

```bash
arch_fixture() {
  cat > "$CASE_ROOT/os-release" <<'OS'
ID=arch
NAME="Arch Linux"
OS
  stub_logger pacman
  stub_command sudo 'printf "sudo %s\\n" "$*" >> "$LOG"; if [ "${STUB_SUDO_FAIL:-0}" = 1 ]; then exit 42; fi'
}

test_arch_installs_required_packages() {
  new_case arch-packages
  arch_fixture
  DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup arch
  assert_status 0 &&
    grep -F "sudo pacman -S --needed" "$LOG" >/dev/null &&
    grep -F "base-devel" "$LOG" >/dev/null &&
    grep -F "niri" "$LOG" >/dev/null &&
    grep -F "quickshell" "$LOG" >/dev/null &&
    grep -F "gpu-screen-recorder" "$LOG" >/dev/null
}

test_arch_package_failure_stops_before_links() {
  new_case arch-failure
  arch_fixture
  STUB_SUDO_FAIL=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup arch
  assert_status 42 && [ ! -e "$HOME/.config/niri" ]
}
```

- [ ] **Step 2: Run tests and verify they fail**

Run: `bash tests/dotfiles_setup_test.sh`

Expected: Arch package aggregation does not contain the config and nbshell packages; failure status/link guard is not satisfied.

- [ ] **Step 3: Implement Arch package-file parsing and aggregation**

Add:

```bash
read_package_file() {
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$1" | tr '\n' ' '
}

arch_packages_for() {
  local wanted="$1" entry owner command_name brew_kind brew_package arch_package packages="$ARCH_BASE_PACKAGES"
  for entry in "${SOFTWARE_TABLE[@]}"; do
    owner="${entry%%|*}"
    software_selected "$owner" "$wanted" || continue
    entry="${entry#*|}"; command_name="${entry%%|*}"
    entry="${entry#*|}"; brew_kind="${entry%%|*}"
    entry="${entry#*|}"; brew_package="${entry%%|*}"
    arch_package="${entry#*|}"
    [ "$arch_package" = "-" ] || packages="$packages $arch_package"
  done
  if software_selected nbshell "$wanted"; then
    packages="$packages $(read_package_file "$DOTFILES/nbshell/packages.arch.txt")"
  fi
  printf '%s\n' "$packages"
}

install_arch_setup_packages() {
  local wanted="$1" packages
  command -v pacman >/dev/null 2>&1 || {
    echo "dotfiles: pacman is required for setup arch" >&2
    return 1
  }
  command -v sudo >/dev/null 2>&1 || {
    echo "dotfiles: sudo is required for setup arch" >&2
    return 1
  }
  packages="$(arch_packages_for "$wanted")"
  sudo pacman -S --needed $packages
}
```

In `cmd_setup`, use `install_arch_setup_packages "$wanted"` for Arch instead of a base-only call. This deliberately performs one required pacman transaction.

- [ ] **Step 4: Prevent duplicate Arch package installation**

Add an optional platform/mode parameter to `run_software_install`:

```bash
run_software_install() {
  local wanted="$1" skip_arch="${2:-0}"
  # existing locals...
```

Guard its Arch collection branch:

```bash
elif [ "$skip_arch" != 1 ] && command -v pacman >/dev/null 2>&1 && [ "$arch_package" != "-" ]; then
```

The later setup configuration phase will call `run_software_install "$wanted" 1`; existing `install` and `deps` calls remain unchanged.

- [ ] **Step 5: Run syntax and tests**

Run:

```bash
bash -n bin/dotfiles
bash tests/dotfiles_setup_test.sh
```

Expected: all tests pass; Arch logs one `sudo pacman -S --needed ...` transaction and a forced status 42 creates no Niri link.

- [ ] **Step 6: Commit**

```bash
git add bin/dotfiles tests/dotfiles_setup_test.sh
git commit -m "feat(dotfiles): install Arch setup packages"
```

### Task 5: Split configuration runtime phases and complete setup orchestration

**Files:**
- Modify: `bin/dotfiles`
- Modify: `tests/dotfiles_setup_test.sh`
- Test: `tests/dotfiles_setup_test.sh`

**Interfaces:**
- Consumes: validated preset entries and completed package stage.
- Produces: `run_config_runtimes(wanted)`, `install_selected(wanted, install_software)`, completed `cmd_setup`, Arch herdr fallback, and manual follow-up output.

- [ ] **Step 1: Add failing tests for preset links, exclusions, and manual boundaries**

Add tests using stubs for user-local installers (`git`, `npm`, `herdr`, or explicit test mode as needed) so the production scripts cannot access the network:

```bash
test_arch_links_primary_stack_only() {
  new_case arch-links
  arch_fixture
  stub_logger npm
  stub_logger git
  stub_logger herdr
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup arch
  assert_status 0 &&
    [ -L "$HOME/.config/niri" ] &&
    [ -L "$HOME/.config/nbshell/config.json" ] &&
    [ -L "$HOME/.config/kitty/kitty.conf" ] &&
    [ ! -e "$HOME/.config/waybar" ] &&
    [ ! -e "$HOME/.config/clavis" ] &&
    [ ! -e "$HOME/.config/kaku" ]
}

test_arch_prints_but_does_not_enable_services() {
  new_case arch-manual
  arch_fixture
  stub_command systemctl 'echo systemctl-executed >> "$LOG"; exit 99'
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup arch
  assert_status 0 &&
    assert_contains "systemctl --user enable --now nbshell.service" &&
    assert_contains "sudo systemctl enable --now tuned.service" &&
    ! grep -F "systemctl-executed" "$LOG" >/dev/null
}

test_macos_links_primary_stack_only() {
  new_case macos-links
  stub_logger brew
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Darwin run_cli setup macos
  assert_status 0 &&
    [ -L "$HOME/.aerospace.toml" ] &&
    [ -L "$HOME/.config/nvim" ] &&
    [ -L "$HOME/.config/kitty/kitty.conf" ] &&
    [ ! -e "$HOME/.config/niri" ] &&
    [ ! -e "$HOME/.config/waybar" ]
}
```

`DOTFILES_SKIP_RUNTIME_INSTALLERS=1` is a test-only seam: it skips network/build side effects but must still print the runtime stage and perform links.

- [ ] **Step 2: Run tests and verify they fail**

Run: `bash tests/dotfiles_setup_test.sh`

Expected: setup currently stops after packages, so required links and manual text are absent.

- [ ] **Step 3: Extract runtime behavior from `cmd_install`**

Introduce:

```bash
run_config_runtimes() {
  local wanted="$1"
  if [ "${DOTFILES_SKIP_RUNTIME_INSTALLERS:-0}" = 1 ]; then
    echo "skip    config runtime installers (test mode)"
    return 0
  fi
  if software_selected herdr "$wanted"; then run_herdr_plugins; fi
  if software_selected zshrc "$wanted"; then run_zsh_deps; fi
  if software_selected clavis "$wanted"; then
    echo "== clavis (user-local, never sudo) =="
    bash "$DOTFILES/clavis/install.sh"
  fi
  if software_selected nbshell "$wanted"; then
    echo "== nbshell (user-local, never sudo) =="
    bash "$DOTFILES/nbshell/install.sh"
  fi
  if software_selected pi-settings "$wanted"; then
    echo "== pi =="
    setup_pi_theme
    if [ ! -f "$HOME/.pi/agent/auth.json" ]; then
      echo "No pi API key yet. Create it (no login, providers are key-based):"
      echo "  printf '{\"$PI_DEFAULT_PROVIDER\": {\"type\": \"api_key\", \"key\": \"sk-...\"}}' > $HOME/.pi/agent/auth.json"
      echo "  chmod 600 $HOME/.pi/agent/auth.json"
    fi
  fi
}
```

Refactor `cmd_install` to:

1. compute `wanted` as it does now;
2. call `cmd_link` using the already selected entries;
3. call `run_software_install "$wanted"`;
4. call `run_config_runtimes "$wanted"`;
5. preserve the existing pi-specific final message.

This removes the five parallel `want_*` flags and makes setup able to reuse the same runtime phase.

- [ ] **Step 4: Complete `cmd_setup` stages**

After packages succeed:

```bash
echo "== install config software =="
if [ "$preset" = arch ]; then
  run_software_install "$wanted" 1
else
  run_software_install "$wanted"
fi

echo "== link configs =="
select_entries $wanted
cmd_link

echo "== install config runtimes =="
run_config_runtimes "$wanted"

echo "== manual follow-up =="
case "$preset" in
  macos)
    echo "Start AeroSpace and grant Accessibility permission when prompted."
    echo "Optional: change the login shell manually with chsh."
    ;;
  arch)
    echo "  systemctl --user enable --now nbshell.service"
    echo "  sudo systemctl enable --now tuned.service"
    ;;
esac
```

Before `run_config_runtimes` on Arch, if `herdr` is still absent, invoke the official user-local installer through a fixed constant:

```bash
HERDR_INSTALL_URL="${DOTFILES_HERDR_INSTALL_URL:-https://herdr.dev/install.sh}"
```

Use the same injectable bootstrap Bash approach as Homebrew. Failure to install required `herdr` is fatal; inability to install `herdr-scratch` on Arch prints an optional warning and continues.

- [ ] **Step 5: Add required-stage failure and idempotence tests**

Add:

```bash
test_existing_links_and_commands_are_skipped() {
  new_case idempotent
  stub_logger brew
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Darwin run_cli setup macos
  assert_status 0
  : > "$LOG"
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Darwin run_cli setup macos
  assert_status 0 && assert_contains "ok      aerospace" && [ -L "$HOME/.aerospace.toml" ]
}

test_runtime_failure_is_fatal() {
  new_case runtime-failure
  stub_logger brew
  stub_command git 'exit 37'
  DOTFILES_UNAME=Darwin run_cli setup macos
  assert_status 37
}
```

If `zsh/install-deps.sh` maps a failing Git command to a different non-zero status, assert non-zero rather than exactly 37 and verify the final manual-follow-up heading is absent.

- [ ] **Step 6: Run syntax and full tests**

Run:

```bash
bash -n bin/dotfiles
bash tests/dotfiles_setup_test.sh
```

Expected: all setup tests pass; no real service commands or package managers execute.

- [ ] **Step 7: Commit**

```bash
git add bin/dotfiles tests/dotfiles_setup_test.sh
git commit -m "feat(dotfiles): configure primary system presets"
```

### Task 6: Add regression smoke tests for existing CLI commands

**Files:**
- Modify: `tests/dotfiles_setup_test.sh`
- Test: `tests/dotfiles_setup_test.sh`

**Interfaces:**
- Consumes: existing CLI contracts for `list`, `status`, `link`, `install`, and `deps`.
- Produces: regression tests proving setup refactoring did not change those command contracts.

- [ ] **Step 1: Add smoke tests**

Add:

```bash
test_existing_commands_smoke() {
  new_case existing-smoke
  run_cli list
  assert_status 0 && assert_contains "dotfiles-cli" || return 1

  run_cli status fastfetch
  assert_status 0 && assert_contains "fastfetch" || return 1

  run_cli link fastfetch
  assert_status 0 && [ -L "$HOME/.config/fastfetch" ] || return 1

  stub_logger brew
  run_cli deps fastfetch
  assert_status 0 || return 1

  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 run_cli install fastfetch
  assert_status 0 && [ -L "$HOME/.config/fastfetch" ]
}
```

Add a no-argument usage assertion:

```bash
test_usage_lists_setup() {
  new_case usage
  run_cli
  assert_status 1 && assert_contains "setup [auto|macos|arch]"
}
```

- [ ] **Step 2: Run tests**

Run: `bash tests/dotfiles_setup_test.sh`

Expected: all tests pass, including setup and legacy smoke tests.

- [ ] **Step 3: Run static checks**

Run:

```bash
bash -n bin/dotfiles
bash -n tests/dotfiles_setup_test.sh
git diff --check
```

Expected: all commands exit 0 with no output from the syntax/diff checks.

- [ ] **Step 4: Commit**

```bash
git add tests/dotfiles_setup_test.sh
git commit -m "test(dotfiles): preserve existing CLI behavior"
```

### Task 7: Document system setup and perform final verification

**Files:**
- Modify: `README.md`
- Modify: `bin/README.md`
- Test: `tests/dotfiles_setup_test.sh`

**Interfaces:**
- Consumes: final CLI behavior and exact manual follow-up commands.
- Produces: user-facing setup documentation matching implementation.

- [ ] **Step 1: Update root setup examples**

In `README.md`, add the primary bootstrap flow:

```bash
git clone https://github.com/aBER0724/dotfiles.git ~/dotfiles
bash ~/dotfiles/bin/dotfiles setup auto

# Or require an explicit matching host:
bash ~/dotfiles/bin/dotfiles setup macos
bash ~/dotfiles/bin/dotfiles setup arch
```

State that macOS bootstraps Homebrew if missing, Arch requires working `sudo`/`pacman`, config conflicts are backed up, and service/login-shell/API-key changes remain manual.

- [ ] **Step 2: Update CLI reference**

In `bin/README.md`:

- change usage to `dotfiles {list|status|link|install|deps|setup} ...`;
- add the three setup invocations;
- list macOS and Arch preset members;
- document excluded rollback configs;
- document Homebrew bootstrap and Arch `nbshell/packages.arch.txt` installation;
- include the exact manual commands:

```bash
systemctl --user enable --now nbshell.service
sudo systemctl enable --now tuned.service
```

- [ ] **Step 3: Run complete verification**

Run:

```bash
bash -n bin/dotfiles
bash -n tests/dotfiles_setup_test.sh
bash tests/dotfiles_setup_test.sh
git diff --check
git status --short
```

Expected:

- both syntax checks exit 0;
- every shell test reports `ok` and the summary has zero failures;
- `git diff --check` prints nothing;
- status lists only the intended CLI, test, and documentation changes.

- [ ] **Step 4: Review dangerous-operation boundaries**

Run:

```bash
grep -nE 'rm -rf|systemctl|chsh|pacman|Homebrew/install' bin/dotfiles tests/dotfiles_setup_test.sh README.md bin/README.md
```

Verify manually from output:

- production code contains no `rm -rf`;
- test cleanup targets only `$TEST_ROOT` created by `mktemp -d`;
- `systemctl` and `chsh` occur only as printed manual guidance or test stubs;
- pacman always uses `sudo pacman -S --needed`;
- Homebrew uses the fixed official URL.

- [ ] **Step 5: Commit documentation**

```bash
git add README.md bin/README.md
git commit -m "docs(dotfiles): document one-command system setup"
```

- [ ] **Step 6: Show the final commit range without pushing**

Run:

```bash
git log --oneline 48d4c64..HEAD
git status --short
```

Expected: the feature/test/docs commits are listed and the working tree is clean. Do not push unless the user explicitly requests it.
