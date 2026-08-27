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
  local name="$1" body="$2"
  printf '#!/bin/sh\n%s\n' "$body" > "$STUB_BIN/$name"
  chmod +x "$STUB_BIN/$name"
}

stub_logger() {
  local command_name="$1"
  stub_command "$command_name" 'printf "%s %s\n" "$(basename "$0")" "$*" >> "$LOG"'
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
  stub_logger brew
  DOTFILES_UNAME=Darwin run_cli setup auto
  assert_status 0 && assert_contains "preset  macos"
}

test_auto_detects_arch() {
  new_case auto-arch
  cat > "$CASE_ROOT/os-release" <<'OS'
ID=arch
NAME="Arch Linux"
OS
  stub_logger pacman
  stub_command sudo 'printf "sudo %s\n" "$*" >> "$LOG"'
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup auto
  assert_status 0 && assert_contains "preset  arch"
}
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
test_macos_bootstraps_homebrew() {
  new_case macos-bootstrap
  stub_command curl 'printf "curl %s\n" "$*" >> "$LOG"; printf "#!/bin/sh\nexit 0\n"'
  stub_command bootstrap-bash 'printf "bootstrap-bash %s\n" "$*" >> "$LOG"'
  stub_command brew 'printf "brew %s\n" "$*" >> "$LOG"'
  DOTFILES_UNAME=Darwin DOTFILES_FORCE_NO_BREW=1 DOTFILES_BASH_BIN="$STUB_BIN/bootstrap-bash" run_cli setup macos
  assert_status 0 && grep -F "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" "$LOG" >/dev/null
}

test_macos_skips_homebrew_bootstrap() {
  new_case macos-existing-brew
  stub_logger brew
  stub_command curl 'echo unexpected-curl >> "$LOG"; exit 99'
  DOTFILES_UNAME=Darwin run_cli setup macos
  assert_status 0 && ! grep -F "unexpected-curl" "$LOG" >/dev/null
}

arch_fixture() {
  cat > "$CASE_ROOT/os-release" <<'OS'
ID=arch
NAME="Arch Linux"
OS
  stub_logger pacman
  stub_command sudo 'printf "sudo %s\n" "$*" >> "$LOG"; if [ "${STUB_SUDO_FAIL:-0}" = 1 ]; then exit 42; fi'
}

test_arch_installs_required_packages() {
  new_case arch-packages
  arch_fixture
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup arch
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

test_existing_links_and_commands_are_skipped() {
  new_case idempotent
  stub_logger brew
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Darwin run_cli setup macos
  assert_status 0 || return 1
  : > "$LOG"
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Darwin run_cli setup macos
  assert_status 0 && assert_contains "ok      aerospace" && [ -L "$HOME/.aerospace.toml" ]
}

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

test_usage_lists_setup() {
  new_case usage
  run_cli
  assert_status 1 && assert_contains "setup [auto|macos|arch]"
}


run_test "auto detects macOS" test_auto_detects_macos
run_test "auto detects Arch" test_auto_detects_arch
run_test "macOS preset rejects Linux" test_macos_rejects_linux
run_test "Arch preset rejects macOS" test_arch_rejects_macos
run_test "unknown preset fails" test_unknown_preset_fails
run_test "macOS bootstraps Homebrew" test_macos_bootstraps_homebrew
run_test "macOS skips Homebrew bootstrap" test_macos_skips_homebrew_bootstrap
run_test "Arch installs required packages" test_arch_installs_required_packages
run_test "Arch package failure stops before links" test_arch_package_failure_stops_before_links
run_test "Arch links primary stack only" test_arch_links_primary_stack_only
run_test "Arch prints services without enabling" test_arch_prints_but_does_not_enable_services
run_test "macOS links primary stack only" test_macos_links_primary_stack_only
run_test "setup is idempotent" test_existing_links_and_commands_are_skipped
run_test "existing commands smoke" test_existing_commands_smoke
run_test "usage lists setup" test_usage_lists_setup

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
