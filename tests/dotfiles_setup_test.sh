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
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Darwin run_cli setup auto
  assert_status 0 && assert_contains "preset   macos"
}

test_auto_detects_arch() {
  new_case auto-arch
  cat > "$CASE_ROOT/os-release" <<'OS'
ID=arch
NAME="Arch Linux"
OS
  stub_logger pacman
  stub_logger brew
  stub_command sudo 'printf "sudo %s\n" "$*" >> "$LOG"'
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_SKIP_SERVER_TOOLS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup auto
  assert_status 0 && assert_contains "preset   linux-omarchy"
}

debian_fixture() {
  cat > "$CASE_ROOT/os-release" <<'OS'
ID=ubuntu
ID_LIKE=debian
NAME="Ubuntu"
OS
  stub_logger apt-get
  stub_logger brew
  stub_command sudo 'printf "sudo %s\n" "$*" >> "$LOG"; if [ "${STUB_SUDO_FAIL:-0}" = 1 ]; then exit 42; fi'
}

test_auto_detects_ubuntu_server() {
  new_case auto-ubuntu
  debian_fixture
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_SKIP_SERVER_TOOLS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup auto
  assert_status 0 &&
    assert_contains "profile  server" &&
    assert_contains "preset   linux-server"
}

test_server_shortcut_runs_as_root() {
  new_case server-root-shortcut
  debian_fixture
  stub_command id 'if [ "$1" = "-u" ]; then echo 0; else /usr/bin/id "$@"; fi'
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_SKIP_SERVER_TOOLS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup server
  assert_status 0 &&
    assert_contains "preset   linux-server" &&
    grep -F "apt-get update" "$LOG" >/dev/null &&
    ! grep -F "sudo apt-get" "$LOG" >/dev/null &&
    ! grep -F "brew" "$LOG" >/dev/null
}
server_nvim_fixture() {
  debian_fixture
  stub_logger node
  stub_logger herdr
  stub_logger yazi
  stub_logger fastfetch
  stub_command uname 'if [ "$1" = "-m" ]; then echo x86_64; else /usr/bin/uname "$@"; fi'
  stub_command id 'if [ "$1" = "-u" ]; then echo 0; else /usr/bin/id "$@"; fi'
  stub_command tar 'printf "tar %s\n" "$*" >> "$LOG"; mkdir -p "$4/nvim-linux-x86_64"'
  stub_command cp 'printf "cp %s\n" "$*" >> "$LOG"'
  stub_command curl 'printf "curl %s\n" "$*" >> "$LOG"; out=""; while [ "$#" -gt 0 ]; do if [ "$1" = "-o" ]; then shift; out="$1"; break; fi; shift; done; [ -z "$out" ] || : > "$out"'
}

test_server_upgrades_old_neovim() {
  new_case server-old-neovim
  server_nvim_fixture
  stub_command nvim 'exit 1'
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux server
  assert_status 0 &&
    assert_contains "install Neovim v0.12.5 from GitHub release" &&
    grep -F "curl -fsSL https://github.com/neovim/neovim/releases/download/v0.12.5/nvim-linux-x86_64.tar.gz" "$LOG" >/dev/null &&
    grep -F "cp -R" "$LOG" | grep -F "/usr/local/" >/dev/null
}

test_server_keeps_current_neovim() {
  new_case server-current-neovim
  server_nvim_fixture
  stub_command nvim 'exit 0'
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux server
  assert_status 0 &&
    assert_not_contains "install Neovim v0.12.5 from GitHub release" &&
    ! grep -F "neovim/releases/download" "$LOG" >/dev/null
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
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_SKIP_SERVER_TOOLS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux server
  assert_status 0 &&
    grep -F "sudo apt-get update" "$LOG" >/dev/null &&
    grep -F "sudo apt-get install -y" "$LOG" | grep -F "build-essential" | grep -F "golang-go" | grep -F "tmux" >/dev/null &&
    ! grep -F "pacman" "$LOG" >/dev/null
}

test_server_excludes_desktop_stack() {
  new_case server-links
  debian_fixture
  stub_logger npm
  stub_logger git
  stub_logger herdr
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_SKIP_SERVER_TOOLS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux server
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
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Darwin DOTFILES_FORCE_NO_BREW=1 DOTFILES_BASH_BIN="$STUB_BIN/bootstrap-bash" run_cli setup macos
  assert_status 0 && grep -F "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" "$LOG" >/dev/null
}

test_macos_skips_homebrew_bootstrap() {
  new_case macos-existing-brew
  stub_logger brew
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
  stub_logger brew
  stub_command sudo 'printf "sudo %s\n" "$*" >> "$LOG"; if [ "${STUB_SUDO_FAIL:-0}" = 1 ]; then exit 42; fi'
}

test_arch_alias_is_compatible() {
  new_case arch-alias
  arch_fixture
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_SKIP_SERVER_TOOLS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup arch
  assert_status 0 &&
    assert_contains "deprecated: 'setup arch' is now 'setup linux omarchy'" &&
    assert_contains "preset   linux-omarchy"
}

test_arch_installs_required_packages() {
  new_case arch-packages
  arch_fixture
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_SKIP_SERVER_TOOLS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux omarchy
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
  DOTFILES_MISSING_SOFTWARE="go cargo yazi tmux" \
    DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_SKIP_SERVER_TOOLS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux omarchy
  assert_status 0 &&
    grep -F "sudo pacman -S --needed" "$LOG" | grep -F "rust" | grep -F "yazi" >/dev/null
}

test_macos_installs_herdr_plugin_build_deps() {
  new_case macos-herdr-build-deps
  stub_logger brew
  # An Omarchy host already ships go/cargo/yazi/tmux, and the software step
  # skips whatever it finds on PATH; name them missing so the brew path runs.
  DOTFILES_MISSING_SOFTWARE="go cargo yazi tmux" \
    DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_UNAME=Darwin run_cli setup macos
  assert_status 0 &&
    grep -F "brew install" "$LOG" | grep -F "rust" | grep -F "yazi" >/dev/null
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
  stub_logger npm
  stub_logger git
  stub_logger herdr
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_SKIP_SERVER_TOOLS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux omarchy
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
  stub_logger npm
  stub_logger git
  stub_logger herdr
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_SKIP_SERVER_TOOLS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux niri
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
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_SKIP_SERVER_TOOLS=1 DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux omarchy
  assert_status 0 &&
    assert_contains "environment.d/fcitx.conf" &&
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

test_arch_bootstraps_linuxbrew_without_scratch_cask() {
  new_case arch-linuxbrew
  arch_fixture
  stub_command curl 'printf "curl %s\n" "$*" >> "$LOG"; printf "#!/bin/sh\nexit 0\n"'
  stub_command bootstrap-bash 'printf "bootstrap-bash %s\n" "$*" >> "$LOG"'
  stub_logger brew
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_FORCE_NO_BREW=1 DOTFILES_BASH_BIN="$STUB_BIN/bootstrap-bash" DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux omarchy
  assert_status 0 &&
    ! grep -F "python-xattr" "$LOG" >/dev/null &&
    grep -F "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" "$LOG" >/dev/null &&
    ! grep -F "brew install --cask" "$LOG" >/dev/null &&
    ! grep -F "macintacos/tap/herdr-scratch" "$LOG" >/dev/null
}

test_arch_installs_native_packages_before_homebrew() {
  new_case arch-native-first
  arch_fixture
  stub_command curl 'printf "curl %s\n" "$*" >> "$LOG"; printf "#!/bin/sh\nexit 0\n"'
  stub_command bootstrap-bash 'printf "bootstrap-bash %s\n" "$*" >> "$LOG"'
  DOTFILES_SKIP_RUNTIME_INSTALLERS=1 DOTFILES_FORCE_NO_BREW=1 DOTFILES_BASH_BIN="$STUB_BIN/bootstrap-bash" DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$CASE_ROOT/os-release" run_cli setup linux omarchy
  assert_status 0 || return 1
  pacman_line="$(grep -nF 'sudo pacman -S --needed' "$LOG" | head -n 1 | cut -d: -f1)"
  bootstrap_line="$(grep -nF 'bootstrap-bash -c' "$LOG" | head -n 1 | cut -d: -f1)"
  [ -n "$pacman_line" ] && [ -n "$bootstrap_line" ] && [ "$pacman_line" -lt "$bootstrap_line" ] &&
    grep -F "sudo pacman -S --needed" "$LOG" | grep -F "file" | grep -F "procps-ng" >/dev/null
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
    assert_contains "bash ~/dotfiles/bin/dotfiles deps herdr" &&
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
  stub_command git 'printf "git %s\n" "$*" >> "$LOG"; dest=""; for arg in "$@"; do dest="$arg"; done; mkdir -p "$dest/.git"; case "$dest" in */.oh-my-zsh) printf "# stub\n" > "$dest/oh-my-zsh.sh" ;; esac'
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

  stub_logger brew
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

run_test "server upgrades old Neovim" test_server_upgrades_old_neovim
run_test "server keeps current Neovim" test_server_keeps_current_neovim
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
run_test "Arch bootstraps Linuxbrew without scratch cask" test_arch_bootstraps_linuxbrew_without_scratch_cask
run_test "Arch installs native packages before Homebrew" test_arch_installs_native_packages_before_homebrew
run_test "Arch installs scratch through herdr" test_arch_installs_scratch_through_herdr
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
