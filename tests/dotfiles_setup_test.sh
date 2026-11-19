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
  # Every case runs `dotfiles setup`, which would otherwise reach the real
  # package managers: `npm install -g` from a sandbox HOME tries to write
  # /usr/lib/node_modules and fails with EACCES (npm exits 243), turning every
  # setup assertion into "expected 0, got 243".
  stub_logger npm
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

# No-network git clone: records the call, creates the destination (and a
# marker oh-my-zsh.sh so install-deps.sh sees the clone as done).
stub_git_clone() {
  stub_command git 'printf "git %s\n" "$*" >> "$LOG"; dest=""; for arg in "$@"; do dest="$arg"; done; mkdir -p "$dest/.git"; case "$dest" in */.oh-my-zsh) printf "# stub\n" > "$dest/oh-my-zsh.sh" ;; esac'
}

# Fake mise: `mise install` drops executable stubs into $STUB_BIN/fake-bin so
# `command -v` (used by the prefer-mise fallback check) sees them. The shim
# dir only covers SOFTWARE_TABLE commands; profile-TOML tools are trusted.
stub_mise_install() {
  stub_command mise 'printf "mise %s\n" "$*" >> "$LOG"
case "$1" in
  install)
    shift
    mkdir -p "$STUB_BIN/fake-bin"
    for spec in "$@"; do
      name="${spec##*:}"
      case "$name" in
        neovim) name=nvim ;; rust) name=cargo ;; npm:*) name="${spec##*/}" ;;
      esac
      case "$name" in *@*) name="${name##*/}" ;; esac
      printf "#!/bin/sh\nexit 0\n" > "$STUB_BIN/fake-bin/$name"
      chmod +x "$STUB_BIN/fake-bin/$name"
    done
    # bare `mise install` (profile sync): cover every table command the
    # profile owns so fallbacks do not fire
    if [ $# -eq 0 ]; then
      for name in nvim node pi herdr go tmux cargo yazi fastfetch lazygit; do
        printf "#!/bin/sh\nexit 0\n" > "$STUB_BIN/fake-bin/$name"
        chmod +x "$STUB_BIN/fake-bin/$name"
      done
    fi
    ;;
esac'
}

run_cli() {
  OUTPUT="$CASE_ROOT/output"
  STATUS=0
  PATH="$STUB_BIN/fake-bin:$STUB_BIN:/usr/bin:/bin" \
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
    echo "--- last output ($name) ---" >&2; tail -20 "$OUTPUT" >&2
    echo "--- commands.log ($name) ---" >&2; cat "$LOG" >&2
  fi
}

test_auto_detects_macos() {
  new_case auto-macos
  stub_logger brew
  stub_mise_install
  stub_git_clone
  DOTFILES_UNAME=Darwin run_cli setup auto
  assert_status 0 && assert_contains "preset   macos"
}

test_auto_detects_arch() {
  new_case auto-arch
  cat > "$CASE_ROOT/os-release" <<'OS'
ID=arch
NAME="Arch Linux"
OS
  stub_logger pacman
  stub_logger mise
  stub_command sudo 'printf "sudo %s\n" "$*" >> "$LOG"'
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup auto
  assert_status 0 && assert_contains "preset   linux-omarchy"
}

debian_fixture() {
  cat > "$CASE_ROOT/os-release" <<'OS'
ID=ubuntu
ID_LIKE=debian
NAME="Ubuntu"
OS
  stub_logger apt-get
  stub_mise_install
  stub_command sudo 'printf "sudo %s\n" "$*" >> "$LOG"; if [ "${STUB_SUDO_FAIL:-0}" = 1 ]; then exit 42; fi; "$@"'
}
test_auto_detects_ubuntu_server() {
  new_case auto-ubuntu
  debian_fixture
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup auto
  assert_status 0 &&
    assert_contains "profile  server" &&
    assert_contains "preset   linux-server"
}

test_server_shortcut_runs_as_root() {
  new_case server-root-shortcut
  debian_fixture
  stub_command id 'if [ "$1" = "-u" ]; then echo 0; else /usr/bin/id "$@"; fi'
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup server
  assert_status 0 &&
    assert_contains "preset   linux-server" &&
    grep -F "apt-get update" "$LOG" >/dev/null &&
    ! grep -F "sudo apt-get" "$LOG" >/dev/null &&
    ! grep -F "brew" "$LOG" >/dev/null
}
test_server_installs_tools_via_mise() {
  new_case server-mise-tools
  debian_fixture
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux server
  assert_status 0 &&
    assert_contains "install mise profile tools (mise/linux-server.toml)" &&
    grep -Fx "mise install" "$LOG" >/dev/null &&
    ! grep -F "sudo apt-get install -y" "$LOG" | grep -F "tmux" >/dev/null &&
    [ -L "$HOME/.config/mise/config.toml" ] &&
    [ "$(readlink "$HOME/.config/mise/config.toml")" = "$REPO/mise/linux-server.toml" ]
}

test_mise_bootstraps_when_missing() {
  new_case mise-bootstrap
  cat > "$CASE_ROOT/mise-stub" <<EOF
#!/bin/sh
printf "mise %s\\n" "\$*" >> "$LOG"
EOF
  chmod +x "$CASE_ROOT/mise-stub"
  cat > "$STUB_BIN/curl" <<EOF
#!/bin/sh
printf "curl %s\\n" "\$*" >> "$LOG"
printf 'cp %s/mise-stub %s/mise\nchmod +x %s/mise\n' "$CASE_ROOT" "$STUB_BIN" "$STUB_BIN"
EOF
  chmod +x "$STUB_BIN/curl"
  DOTFILES_UNAME=Darwin run_cli deps mise
  assert_status 0 &&
    assert_contains "install mise from https://mise.run" &&
    grep -F "curl -fsSL https://mise.run" "$LOG" >/dev/null &&
    [ -L "$HOME/.config/mise/config.toml" ] &&
    [ "$(readlink "$HOME/.config/mise/config.toml")" = "$REPO/mise/macos.toml" ]
}
test_root_rejected_for_omarchy() {
  new_case root-omarchy
  arch_fixture
  stub_command id 'if [ "$1" = "-u" ]; then echo 0; else /usr/bin/id "$@"; fi'
  DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux omarchy
  assert_status 1 && assert_contains "root setup is supported only" && [ ! -s "$LOG" ]
}

test_server_installs_apt_packages() {
  new_case server-packages
  debian_fixture
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux server
  assert_status 0 &&
    grep -F "sudo apt-get update" "$LOG" >/dev/null &&
    grep -F "sudo apt-get install -y" "$LOG" | grep -F "build-essential" | grep -F "ca-certificates" >/dev/null &&
    ! grep -F "sudo apt-get install -y" "$LOG" | grep -F "golang-go" >/dev/null &&
    ! grep -F "pacman" "$LOG" >/dev/null
}

test_server_excludes_desktop_stack() {
  new_case server-links
  debian_fixture
  stub_logger git
  stub_logger herdr
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux server
  assert_status 0 &&
    [ -L "$HOME/.config/nvim" ] &&
    [ -L "$HOME/.config/herdr/config.toml" ] &&
    [ ! -e "$HOME/.config/niri" ] &&
    [ ! -e "$HOME/.config/nbshell" ] &&
    [ ! -e "$HOME/.config/kitty" ] &&
    assert_contains "no desktop services or nbshell were installed"
}

test_linux_profile_rejects_wrong_distro() {
  new_case wrong-linux-profile
  debian_fixture
  DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux omarchy
  assert_status 1 && assert_contains "requires Arch Linux" && [ ! -s "$LOG" ]
}

test_server_rejects_arch_even_with_apt() {
  new_case server-on-arch
  arch_fixture
  stub_logger apt-get
  DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux server
  assert_status 1 && assert_contains "requires Ubuntu, Debian, or a derivative" && [ ! -s "$LOG" ]
}

test_unknown_linux_profile_fails() {
  new_case unknown-linux-profile
  debian_fixture
  DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux desktop
  assert_status 1 && assert_contains "unknown Linux profile 'desktop'"
}

test_setup_rejects_extra_arguments() {
  new_case extra-arguments
  debian_fixture
  DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux server extra
  assert_status 1 && assert_contains "accepts at most a system and one Linux profile" && [ ! -s "$LOG" ]
}

test_arch_alias_rejects_profile() {
  new_case arch-alias-profile
  arch_fixture
  DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup arch server
  assert_status 1 && assert_contains "alias does not accept a profile" && [ ! -s "$LOG" ]
}

test_server_package_failure_stops_before_links() {
  new_case server-failure
  debian_fixture
  STUB_SUDO_FAIL=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux server
  assert_status 42 &&
    [ ! -e "$HOME/.config/nvim" ] &&
    ! grep -F "brew" "$LOG" >/dev/null
}
test_macos_rejects_linux() {
  new_case reject-macos
  DOTFILES_UNAME=Linux run_cli setup macos
  assert_status 1 && assert_contains "setup macos requires macOS"
  [ ! -s "$LOG" ]
}

test_arch_rejects_macos() {
  new_case reject-arch
  DOTFILES_UNAME=Darwin run_cli setup linux omarchy
  assert_status 1 && assert_contains "setup linux requires Linux"
  [ ! -s "$LOG" ]
}

test_unknown_preset_fails() {
  new_case unknown
  DOTFILES_UNAME=Darwin run_cli setup debian
  assert_status 1 && assert_contains "unknown setup system 'debian'"
}
test_macos_bootstraps_homebrew() {
  new_case macos-bootstrap
  stub_command curl 'printf "curl %s\n" "$*" >> "$LOG"; printf "#!/bin/sh\nexit 0\n"'
  stub_command bootstrap-bash 'printf "bootstrap-bash %s\n" "$*" >> "$LOG"'
  stub_command brew 'printf "brew %s\n" "$*" >> "$LOG"'
  stub_mise_install
  stub_git_clone
  DOTFILES_UNAME=Darwin DOTFILES_FORCE_NO_BREW=1 DOTFILES_BASH_BIN="$STUB_BIN/bootstrap-bash" run_cli setup macos
  assert_status 0 && grep -F "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" "$LOG" >/dev/null
}

test_macos_skips_homebrew_bootstrap() {
  new_case macos-existing-brew
  stub_logger brew
  stub_mise_install
  stub_git_clone
  stub_command curl 'echo unexpected-curl >> "$LOG"; exit 99'
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Darwin run_cli setup macos
  assert_status 0 && ! grep -F "unexpected-curl" "$LOG" >/dev/null
}

arch_fixture() {
  cat > "$CASE_ROOT/os-release" <<'OS'
ID=arch
NAME="Arch Linux"
OS
  stub_logger pacman
  stub_mise_install
  stub_command sudo 'printf "sudo %s\n" "$*" >> "$LOG"; if [ "${STUB_SUDO_FAIL:-0}" = 1 ]; then exit 42; fi; "$@"'
}
test_arch_alias_is_compatible() {
  new_case arch-alias
  arch_fixture
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup arch
  assert_status 0 &&
    assert_contains "deprecated: 'setup arch' is now 'setup linux omarchy'" &&
    assert_contains "preset   linux-omarchy"
}

test_arch_installs_required_packages() {
  new_case arch-packages
  arch_fixture
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux omarchy
  assert_status 0 &&
    grep -F "sudo pacman -S --needed" "$LOG" >/dev/null &&
    grep -F "base-devel" "$LOG" >/dev/null &&
    ! grep -F "python-xattr" "$LOG" >/dev/null &&
    grep -F "fcitx5-im" "$LOG" >/dev/null &&
    grep -F "fcitx5-rime" "$LOG" >/dev/null &&
    grep -F "kitty" "$LOG" >/dev/null &&
    assert_not_contains "no supported package mapping for: nvim niri"
}

test_arch_installs_herdr_plugin_build_deps() {
  new_case arch-herdr-build-deps
  arch_fixture
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux omarchy
  assert_status 0 &&
    assert_contains "install mise profile tools (mise/linux-desktop.toml)" &&
    grep -Fx "mise install" "$LOG" >/dev/null
}

test_macos_installs_herdr_plugin_build_deps() {
  new_case macos-herdr-build-deps
  stub_logger brew
  stub_mise_install
  stub_git_clone
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Darwin run_cli setup macos
  assert_status 0 &&
    assert_contains "install mise profile tools (mise/macos.toml)" &&
    grep -Fx "mise install" "$LOG" >/dev/null
}

test_arch_package_failure_stops_before_links() {
  new_case arch-failure
  arch_fixture
  STUB_SUDO_FAIL=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux omarchy
  assert_status 42 && [ ! -e "$HOME/.config/niri" ]
}


test_arch_links_primary_stack_only() {
  new_case arch-links
  arch_fixture
  stub_logger git
  stub_logger herdr
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux omarchy
  assert_status 0 &&
    [ -L "$HOME/.config/environment.d/fcitx.conf" ] &&
    grep -F "QT_IM_MODULE=fcitx" "$HOME/.config/environment.d/fcitx.conf" >/dev/null &&
    [ -L "$HOME/.config/fcitx5/conf" ] &&
    [ -L "$HOME/.config/kitty/kitty.conf" ] &&
    [ ! -e "$HOME/.config/niri" ] &&
    [ ! -e "$HOME/.config/nbshell" ] &&
    [ ! -e "$HOME/.config/waybar" ] &&
    [ ! -e "$HOME/.config/clavis" ] &&
    [ ! -e "$HOME/.config/kaku" ]
}

test_niri_profile_links_custom_stack() {
  new_case niri-links
  arch_fixture
  stub_logger git
  stub_logger herdr
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux niri
  assert_status 0 &&
    assert_contains "preset   linux-niri" &&
    [ -L "$HOME/.config/niri" ] &&
    [ -L "$HOME/.config/nbshell/config.json" ] &&
    [ -L "$HOME/.config/nbshell/screensaver.txt" ] &&
    [ -L "$HOME/.config/environment.d/fcitx.conf" ] &&
    [ -L "$HOME/.config/fcitx5/conf" ] &&
    [ -L "$HOME/.config/kitty/kitty.conf" ]
}
test_arch_prints_but_does_not_enable_services() {
  new_case arch-manual
  arch_fixture
  stub_command systemctl 'echo systemctl-executed >> "$LOG"; exit 99'
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux omarchy
  assert_status 0 &&
    assert_contains "environment.d/fcitx.conf" &&
    ! grep -F "systemctl-executed" "$LOG" >/dev/null
}

test_macos_links_primary_stack_only() {
  new_case macos-links
  stub_logger brew
  stub_mise_install
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
  stub_mise_install
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Darwin run_cli setup macos
  assert_status 0 || return 1
  : > "$LOG"
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Darwin run_cli setup macos
  assert_status 0 && assert_contains "ok      aerospace" && [ -L "$HOME/.aerospace.toml" ]
}

test_arch_uses_mise_without_homebrew() {
  new_case arch-no-brew
  arch_fixture
  stub_command curl 'echo unexpected-curl >> "$LOG"; exit 99'
  stub_command brew 'echo unexpected-brew >> "$LOG"; exit 99'
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux omarchy
  assert_status 0 &&
    ! grep -F "unexpected-brew" "$LOG" >/dev/null &&
    ! grep -F "unexpected-curl" "$LOG" >/dev/null &&
    ! grep -F "macintacos/tap/herdr-scratch" "$LOG" >/dev/null &&
    assert_contains "install mise profile tools (mise/linux-desktop.toml)"
}

test_arch_installs_native_packages_before_mise() {
  new_case arch-native-first
  arch_fixture
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux omarchy
  assert_status 0 || return 1
  pacman_line="$(grep -nF 'sudo pacman -S --needed' "$LOG" | head -n 1 | cut -d: -f1)"
  mise_line="$(grep -nF 'mise install' "$LOG" | head -n 1 | cut -d: -f1)"
  [ -n "$pacman_line" ] && [ -n "$mise_line" ] && [ "$pacman_line" -lt "$mise_line" ] &&
    grep -F "sudo pacman -S --needed" "$LOG" | grep -F "file" | grep -F "procps-ng" >/dev/null
}

test_macos_installs_sheprd_cask() {
  new_case macos-sheprd
  stub_logger brew
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Darwin run_cli setup macos
  assert_status 0 ||
    return 1
  grep -F "brew install --cask" "$LOG" | grep -F "sheprd-labs/tap/sheprd" >/dev/null
}

test_linux_installs_sheprd_through_upstream_installer() {
  new_case linux-sheprd
  cat > "$CASE_ROOT/sheprd-install.sh" <<'SH'
#!/bin/sh
printf 'sheprd-installer-ran\n' >> "$LOG"
SH
  # The installer is fetched with `curl -o <file>`, so the stub honours -o
  # instead of writing the script to stdout.
  stub_command curl 'printf "curl %s\n" "$*" >> "$LOG"
out=
prev=
for arg in "$@"; do
  [ "$prev" = "-o" ] && out="$arg"
  prev="$arg"
done
if [ -n "$out" ]; then cat "$SHEPRD_TEST_SCRIPT" > "$out"; else cat "$SHEPRD_TEST_SCRIPT"; fi'
  stub_logger brew
  SHEPRD_TEST_SCRIPT="$CASE_ROOT/sheprd-install.sh" DOTFILES_UNAME=Linux run_cli deps sheprd
  assert_status 0 &&
    assert_contains "install sheprd from" &&
    grep -F "sheprd-installer-ran" "$LOG" >/dev/null &&
    ! grep -F "sheprd-labs/tap/sheprd" "$LOG" >/dev/null
}

test_linux_ignores_macos_casks() {
  new_case linux-macos-cask
  stub_logger brew
  DOTFILES_UNAME=Linux run_cli deps aerospace
  assert_status 0 &&
    ! grep -F "nikitabobko/tap/aerospace" "$LOG" >/dev/null
}

test_linux_skips_sheprd_when_present() {
  new_case linux-sheprd-present
  cat > "$CASE_ROOT/sheprd-install.sh" <<'SH'
#!/bin/sh
printf 'sheprd-installer-ran\n' >> "$LOG"
SH
  # The installer is fetched with `curl -o <file>`, so the stub honours -o
  # instead of writing the script to stdout.
  stub_command curl 'printf "curl %s\n" "$*" >> "$LOG"
out=
prev=
for arg in "$@"; do
  [ "$prev" = "-o" ] && out="$arg"
  prev="$arg"
done
if [ -n "$out" ]; then cat "$SHEPRD_TEST_SCRIPT" > "$out"; else cat "$SHEPRD_TEST_SCRIPT"; fi'
  stub_logger sheprd
  SHEPRD_TEST_SCRIPT="$CASE_ROOT/sheprd-install.sh" DOTFILES_UNAME=Linux run_cli deps sheprd
  assert_status 0 &&
    ! grep -F "sheprd-installer-ran" "$LOG" >/dev/null
}

test_arch_installs_scratch_through_herdr() {
  new_case arch-scratch-plugin
  cp "$REPO/herdr/plugins.txt" "$CASE_ROOT/plugins.txt"
  stub_logger go
  stub_logger cargo
  stub_logger yazi
  stub_logger tmux
  stub_logger herdr
  stub_command git 'exit 0'
  OUTPUT="$CASE_ROOT/output"
  STATUS=0
  PATH="$STUB_BIN:/usr/bin:/bin" HOME="$HOME" DOTFILES_UNAME=Linux \
    HERDR_PLUGINS_FILE="$CASE_ROOT/plugins.txt" \
    bash "$REPO/herdr/install-plugins.sh" >"$OUTPUT" 2>&1 || STATUS=$?
  assert_status 0 &&
    grep -F "herdr plugin install macintacos/herdr-scratch -y" "$LOG" >/dev/null &&
    ! grep -F "herdr plugin link" "$LOG" >/dev/null
}

test_mise_failure_falls_back_to_native() {
  new_case mise-fallback
  stub_logger brew
  # mise succeeds for everything EXCEPT ubi specs (herdr ships no macOS asset)
  stub_command mise 'printf "mise %s\n" "$*" >> "$LOG"
case " $* " in *ubi:*) exit 1 ;; esac
case "$1" in
  install)
    shift
    mkdir -p "$STUB_BIN/fake-bin"
    for spec in "$@"; do
      name="${spec##*:}"
      case "$name" in neovim) name=nvim ;; rust) name=cargo ;; *@*) name="${name##*/}" ;; esac
      printf "#!/bin/sh\nexit 0\n" > "$STUB_BIN/fake-bin/$name"
      chmod +x "$STUB_BIN/fake-bin/$name"
    done
    ;;
esac'
  DOTFILES_UNAME=Darwin run_cli deps herdr
  assert_status 0 &&
    assert_contains "install mise tools:" &&
    grep -F "brew install" "$LOG" | grep -F "herdr" >/dev/null &&
    ! grep -F "brew install" "$LOG" | grep -F " tmux" >/dev/null &&
    ! grep -F "brew install" "$LOG" | grep -F " yazi" >/dev/null
}

test_arch_uses_pacman_before_aur() {
  new_case pacman-first
  arch_fixture
  # pacman "succeeds" by materializing the package binary, so verify passes
  # and the AUR fallback never fires.
  stub_command pacman 'echo "pacman $*" >> "$LOG"
mkdir -p "$STUB_BIN/fake-bin"
for pkg in "$@"; do
  case "$pkg" in -* | --*) continue ;; esac
  printf "#!/bin/sh\nexit 0\n" > "$STUB_BIN/fake-bin/$pkg"
  chmod +x "$STUB_BIN/fake-bin/$pkg"
done'
  stub_logger yay
  DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli deps discord
  assert_status 0 &&
    grep -F "pacman -S --needed" "$LOG" | grep -F "discord" >/dev/null &&
    ! grep -F "yay -S" "$LOG" >/dev/null
}

test_pacman_failure_falls_back_to_aur() {
  new_case aur-fallback
  arch_fixture
  stub_command pacman 'echo "pacman $*" >> "$LOG"; exit 1'
  stub_command yay 'echo "yay $*" >> "$LOG"
mkdir -p "$STUB_BIN/fake-bin"
for pkg in "$@"; do
  case "$pkg" in -* | --*) continue ;; esac
  printf "#!/bin/sh\nexit 0\n" > "$STUB_BIN/fake-bin/$pkg"
  chmod +x "$STUB_BIN/fake-bin/$pkg"
done'
  DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli deps discord
  assert_status 0 &&
    assert_contains "install AUR packages (yay): discord" &&
    ! grep -F "manual" "$OUTPUT" >/dev/null
}

test_aur_without_helper_lands_in_manual() {
  new_case aur-manual
  arch_fixture
  stub_command pacman 'echo "pacman $*" >> "$LOG"; exit 1'
  DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli deps discord
  assert_status 0 &&
    assert_contains "aur(yay -S discord)"
}

test_macos_skips_scratch_source_build() {
  new_case macos-scratch-cask
  cp "$REPO/herdr/plugins.txt" "$CASE_ROOT/plugins.txt"
  stub_logger go
  stub_logger cargo
  stub_logger yazi
  stub_logger tmux
  stub_logger herdr
  OUTPUT="$CASE_ROOT/output"
  STATUS=0
  PATH="$STUB_BIN:/usr/bin:/bin" HOME="$HOME" DOTFILES_UNAME=Darwin \
    HERDR_PLUGINS_FILE="$CASE_ROOT/plugins.txt" \
    bash "$REPO/herdr/install-plugins.sh" >"$OUTPUT" 2>&1 || STATUS=$?
  assert_status 0 &&
    assert_contains "user.scratch (provided by the macOS Homebrew cask)" &&
    ! grep -F "herdr plugin install macintacos/herdr-scratch" "$LOG" >/dev/null
}

test_gen_plugins_keeps_github_linux_kind() {
  new_case herdr-gen-plugins
  mkdir -p "$HOME/.config/herdr" "$CASE_ROOT/herdr"
  cp "$REPO/herdr/gen-plugins.sh" "$CASE_ROOT/herdr/"
  cat > "$HOME/.config/herdr/plugins.json" <<'JSON'
[
  {"plugin_id": "pinned.pkg", "source": {"kind": "github", "owner": "me", "repo": "pinned", "resolved_commit": "abc123"}},
  {"plugin_id": "user.scratch", "source": {"kind": "github", "owner": "macintacos", "repo": "herdr-scratch", "resolved_commit": "def456"}}
]
JSON
  # scratch is tracked unpinned so Linux rebuilds it from current upstream.
  printf '%s\n' 'user.scratch|github-linux|herdr plugin install macintacos/herdr-scratch' \
    > "$CASE_ROOT/herdr/plugins.txt"
  HOME="$HOME" bash "$CASE_ROOT/herdr/gen-plugins.sh" >/dev/null 2>&1 || return 1
  grep -Fx 'user.scratch|github-linux|herdr plugin install macintacos/herdr-scratch' \
    "$CASE_ROOT/herdr/plugins.txt" >/dev/null &&
    grep -Fx 'pinned.pkg|github|herdr plugin install me/pinned --ref abc123' \
      "$CASE_ROOT/herdr/plugins.txt" >/dev/null
}

test_plugin_failure_shows_actual_log() {
  new_case plugin-failure-log
  printf '%s\n' 'broken|github|herdr plugin install example/broken' > "$CASE_ROOT/plugins.txt"
  stub_logger go
  stub_logger cargo
  stub_logger yazi
  stub_logger tmux
  stub_command herdr 'printf "herdr %s\n" "$*" >> "$LOG"; echo "cargo: linker cc not found" >&2; exit 1'
  OUTPUT="$CASE_ROOT/output"
  STATUS=0
  PATH="$STUB_BIN:/usr/bin:/bin" HOME="$HOME" DOTFILES_UNAME=Linux \
    HERDR_PLUGINS_FILE="$CASE_ROOT/plugins.txt" \
    bash "$REPO/herdr/install-plugins.sh" >"$OUTPUT" 2>&1 || STATUS=$?
  assert_status 1 &&
    assert_contains "cargo: linker cc not found" &&
    assert_contains "failed to install: broken"
}

test_plugin_installer_stops_when_required_deps_missing() {
  new_case plugin-missing-deps
  cp "$REPO/herdr/plugins.txt" "$CASE_ROOT/plugins.txt"
  stub_logger herdr
  stub_logger go
  stub_logger tmux
  OUTPUT="$CASE_ROOT/output"
  STATUS=0
  # cargo and yazi exist in /usr/bin on an Omarchy box, so name the missing
  # dependency explicitly instead of relying on the host not having it.
  PATH="$STUB_BIN:/usr/bin:/bin" HOME="$HOME" DOTFILES_UNAME=Linux \
    HERDR_PLUGIN_DEPS="go tmux missing-dep-for-test" \
    HERDR_PLUGINS_FILE="$CASE_ROOT/plugins.txt" \
    bash "$REPO/herdr/install-plugins.sh" >"$OUTPUT" 2>&1 || STATUS=$?
  assert_status 1 &&
    # The hint prints the real checkout path, not ~/dotfiles.
    assert_contains "bin/dotfiles deps herdr" &&
    [ ! -s "$LOG" ]
}

test_nbshell_installer_removes_bongo_cat() {
  grep -F "remove-bongo-cat.patch" "$REPO/nbshell/install.sh" >/dev/null &&
    grep -F -- '-        void BongoCat.active;' "$REPO/nbshell/remove-bongo-cat.patch" >/dev/null &&
    grep -F -- '-            "id": "bongo",' "$REPO/nbshell/remove-bongo-cat.patch" >/dev/null &&
    grep -F -- '-        case "bongo":' "$REPO/nbshell/remove-bongo-cat.patch" >/dev/null
}

test_zsh_deps_install_oh_my_zsh() {
  new_case zsh-omz
  stub_git_clone
  OUTPUT="$CASE_ROOT/output"
  STATUS=0
  PATH="$STUB_BIN:/usr/bin:/bin" DOTFILES_DIR="$REPO" bash "$REPO/zsh/install-deps.sh" >"$OUTPUT" 2>&1 || STATUS=$?
  assert_status 0 &&
    [ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ] &&
    grep -F "ohmyzsh/ohmyzsh.git $HOME/.oh-my-zsh" "$LOG" >/dev/null
}

test_zshrc_survives_missing_oh_my_zsh() {
  new_case zshrc-missing-omz
  OUTPUT="$CASE_ROOT/output"
  STATUS=0
  HOME="$HOME" USER=tester zsh -f -c "source '$REPO/zsh/zshrc'" >"$OUTPUT" 2>&1 || STATUS=$?
  assert_not_contains "no such file or directory"
}

test_existing_commands_smoke() {
  new_case existing-smoke
  run_cli list
  assert_status 0 && assert_contains "dotfiles-cli" || return 1

  run_cli status fastfetch
  assert_status 0 && assert_contains "fastfetch" || return 1

  run_cli link fastfetch
  assert_status 0 && [ -L "$HOME/.config/fastfetch" ] || return 1

  stub_mise_install
  run_cli deps fastfetch
  assert_status 0 || return 1

  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 run_cli install fastfetch
  assert_status 0 && [ -L "$HOME/.config/fastfetch" ]
}
test_pi_links_agent_skills() {
  new_case pi-agent-skills
  mkdir -p "$HOME/.config/magpie/library/skills" "$HOME/.agents/skills"
  printf 'local skill\n' > "$HOME/.agents/skills/local.txt"
  run_cli link pi
  assert_status 0 &&
    [ -L "$HOME/.agents/skills" ] &&
    [ "$(readlink "$HOME/.agents/skills")" = "$HOME/.config/magpie/library/skills" ] &&
    assert_contains "backup  agent-skills"
}
test_pi_skips_missing_machine_local_source() {
  new_case pi-agent-skills-missing
  # No ~/.config/magpie/library/skills on this machine: the machine-local
  # source is absent, so the entry is skipped instead of linked dead.
  run_cli link pi
  assert_status 0 &&
    [ ! -e "$HOME/.agents/skills" ] &&
    assert_contains "skip    agent-skills"
}

test_pi_prunes_dangling_machine_local_link() {
  new_case pi-agent-skills-dangling
  mkdir -p "$HOME/.agents"
  ln -sfn "$HOME/.config/magpie/library/skills" "$HOME/.agents/skills"
  run_cli link pi
  assert_status 0 &&
    [ ! -e "$HOME/.agents/skills" ] && [ ! -L "$HOME/.agents/skills" ] &&
    assert_contains "prune   agent-skills"
}

test_status_reports_dangling_machine_local_link() {
  new_case pi-agent-skills-dangling-status
  mkdir -p "$HOME/.agents"
  ln -sfn "$HOME/.config/magpie/library/skills" "$HOME/.agents/skills"
  run_cli status pi
  assert_status 0 && assert_contains "DANGLING (source missing)"
}



test_usage_lists_setup() {
  new_case usage
  run_cli
  assert_status 1 && assert_contains "setup [auto|macos|linux|server] [auto|server|omarchy|niri]"
}


run_test "auto detects macOS" test_auto_detects_macos
run_test "auto detects Arch" test_auto_detects_arch
run_test "auto detects Ubuntu server" test_auto_detects_ubuntu_server
run_test "server shortcut runs as root" test_server_shortcut_runs_as_root

run_test "server installs tools via mise" test_server_installs_tools_via_mise
run_test "mise bootstraps when missing" test_mise_bootstraps_when_missing
run_test "root is rejected for Omarchy" test_root_rejected_for_omarchy
run_test "server installs apt packages" test_server_installs_apt_packages
run_test "server excludes desktop stack" test_server_excludes_desktop_stack
run_test "Linux profile rejects wrong distro" test_linux_profile_rejects_wrong_distro
run_test "server rejects Arch even with apt" test_server_rejects_arch_even_with_apt
run_test "unknown Linux profile fails" test_unknown_linux_profile_fails
run_test "setup rejects extra arguments" test_setup_rejects_extra_arguments
run_test "Arch alias rejects profile" test_arch_alias_rejects_profile
run_test "server package failure stops before links" test_server_package_failure_stops_before_links
run_test "Arch compatibility alias works" test_arch_alias_is_compatible
run_test "macOS preset rejects Linux" test_macos_rejects_linux
run_test "Arch preset rejects macOS" test_arch_rejects_macos
run_test "unknown preset fails" test_unknown_preset_fails
run_test "macOS bootstraps Homebrew" test_macos_bootstraps_homebrew
run_test "macOS skips Homebrew bootstrap" test_macos_skips_homebrew_bootstrap
run_test "Arch installs required packages" test_arch_installs_required_packages
run_test "Arch package failure stops before links" test_arch_package_failure_stops_before_links
run_test "Arch links primary stack only" test_arch_links_primary_stack_only
run_test "Niri profile links custom stack" test_niri_profile_links_custom_stack
run_test "Arch prints services without enabling" test_arch_prints_but_does_not_enable_services
run_test "macOS links primary stack only" test_macos_links_primary_stack_only
run_test "setup is idempotent" test_existing_links_and_commands_are_skipped
run_test "Arch installs herdr plugin build deps" test_arch_installs_herdr_plugin_build_deps
run_test "macOS installs herdr plugin build deps" test_macos_installs_herdr_plugin_build_deps
run_test "Arch uses mise without Homebrew" test_arch_uses_mise_without_homebrew
run_test "Arch installs native packages before mise" test_arch_installs_native_packages_before_mise
run_test "macOS installs the sheprd cask" test_macos_installs_sheprd_cask
run_test "Linux installs sheprd upstream" test_linux_installs_sheprd_through_upstream_installer
run_test "Linux skips an installed sheprd" test_linux_skips_sheprd_when_present
run_test "Linux ignores macOS-only casks" test_linux_ignores_macos_casks
run_test "Arch installs scratch through herdr" test_arch_installs_scratch_through_herdr
run_test "mise failure falls back to native" test_mise_failure_falls_back_to_native
run_test "Arch uses pacman before AUR" test_arch_uses_pacman_before_aur
run_test "pacman failure falls back to AUR" test_pacman_failure_falls_back_to_aur
run_test "AUR without helper lands in manual" test_aur_without_helper_lands_in_manual
run_test "macOS skips scratch source build" test_macos_skips_scratch_source_build
run_test "gen-plugins keeps the github-linux kind" test_gen_plugins_keeps_github_linux_kind
run_test "Plugin failure shows actual log" test_plugin_failure_shows_actual_log
run_test "Plugin installer stops when required deps missing" test_plugin_installer_stops_when_required_deps_missing
run_test "nbshell installer removes Bongo Cat" test_nbshell_installer_removes_bongo_cat
run_test "Zsh deps install Oh My Zsh" test_zsh_deps_install_oh_my_zsh
run_test "zshrc survives missing Oh My Zsh" test_zshrc_survives_missing_oh_my_zsh
run_test "existing commands smoke" test_existing_commands_smoke
run_test "pi links curated agent skills" test_pi_links_agent_skills
run_test "pi skips a missing machine-local source" test_pi_skips_missing_machine_local_source
run_test "pi prunes a dangling machine-local link" test_pi_prunes_dangling_machine_local_link
run_test "status reports a dangling machine-local link" test_status_reports_dangling_machine_local_link
run_test "usage lists setup" test_usage_lists_setup

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
