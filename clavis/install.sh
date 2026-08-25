#!/usr/bin/env bash
# Install Clavis Shell and companion tools entirely under ~/.local.
# This script NEVER invokes sudo, pacman, paru, or yay.
set -euo pipefail

PREFIX="${CLAVIS_PREFIX:-$HOME/.local}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/clavis-source-build"
JOBS="${CLAVIS_BUILD_JOBS:-2}"

CLAVIS_REPO="https://github.com/StatIndet/quickshell"
CLAVIS_REV="8a7b1989d8995bd49a0b00cf9c19650f22d54d7b"
KEY_CLI_REPO="https://github.com/StatIndet/key-cli"
KEY_CLI_REV="d512bc1e3607c52c5e1fb4477b9c7f31d9216760"
KEYTOP_REPO="https://github.com/StatIndet/keytop"
KEYTOP_REV="d8731573e8e8641a368696fb48b550fe8ba40"
CAVA_REPO="https://github.com/karlstav/cava"
# Last seven-argument cava_init API consumed by current Clavis.
CAVA_REV="adfe24a51711d240a9f9017088ff3a9a9e291aa0"
WLOGOUT_REPO="https://github.com/ArtsyMacaw/wlogout"
WLOGOUT_REV="2db390f3bb1f57e73b3172a7c24f4c1fe35c0c96"

manual_packages="qt6-tools qt6-lottie qtkeychain-qt6 cava"
required_commands="git cmake ninja pkg-config c++ cc ar npm meson qs"
missing=""
for command_name in $required_commands; do
    command -v "$command_name" >/dev/null 2>&1 || missing="$missing $command_name"
done

if [[ -n "$missing" ]]; then
    cat >&2 <<EOF
Clavis installer: missing commands:$missing
Install the required system packages manually.
Suggested package names: $manual_packages

This installer did not and will not run sudo or a package manager.
EOF
    exit 2
fi

for module in \
    /usr/lib/cmake/Qt6LinguistTools/Qt6LinguistToolsConfig.cmake \
    /usr/lib/qt6/qml/Qt/labs/lottieqt/qmldir; do
    if [[ ! -e "$module" ]]; then
        cat >&2 <<EOF
Clavis installer: required Qt module is missing: $module
Install dependencies manually.
Suggested package names: $manual_packages

No privileged command was executed.
EOF
        exit 2
    fi
done

clone_at() {
    local repo=$1 revision=$2 destination=$3
    if [[ ! -d "$destination/.git" ]]; then
        rm -rf "$destination"
        git clone --filter=blob:none "$repo" "$destination"
    fi
    git -C "$destination" fetch --depth 1 origin "$revision"
    git -C "$destination" checkout --detach "$revision"
}

mkdir -p "$CACHE" "$PREFIX/bin" "$PREFIX/lib/pkgconfig" "$PREFIX/include/cava"

printf '\n== libcava (user-local) ==\n'
clone_at "$CAVA_REPO" "$CAVA_REV" "$CACHE/cava"
rm -rf "$CACHE/cava-build"
cmake -S "$CACHE/cava" -B "$CACHE/cava-build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
cmake --build "$CACHE/cava-build" --target cavacore -j "$JOBS"
install -m 0644 "$CACHE/cava-build/libcavacore.a" "$PREFIX/lib/libcavacore.a"
install -m 0644 "$CACHE/cava/cavacore.h" "$PREFIX/include/cava/cavacore.h"
cat > "$PREFIX/lib/pkgconfig/libcava.pc" <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: libcava
Description: Cava core spectrum processing library (Clavis-compatible)
Version: 0.10.7-git-adfe24a
Libs: -L\${libdir} -lcavacore -lfftw3 -lm
Cflags: -I\${includedir}
EOF
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

printf '\n== Clavis Shell ==\n'
clone_at "$CLAVIS_REPO" "$CLAVIS_REV" "$CACHE/clavis"
rm -rf "$CACHE/clavis-build"
cmake -S "$CACHE/clavis" -B "$CACHE/clavis-build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCLAVIS_QML_INSTALL_DIR="$PREFIX/lib/qt6/qml" \
    -DCLAVIS_CONFIG_INSTALL_DIR="$PREFIX/share/quickshell/clavis" \
    -DCLAVIS_SYSTEMD_USER_INSTALL_DIR="$PREFIX/lib/systemd/user"
cmake --build "$CACHE/clavis-build" -j "$JOBS"
cmake --install "$CACHE/clavis-build"

printf '\n== key-cli ==\n'
clone_at "$KEY_CLI_REPO" "$KEY_CLI_REV" "$CACHE/key-cli"
venv="$PREFIX/share/clavis/key-cli-venv"
rm -rf "$venv"
/usr/bin/python3 -m venv "$venv"
"$venv/bin/pip" install --no-deps "$CACHE/key-cli"
ln -sfn "$venv/bin/key" "$PREFIX/bin/key"
service=$(find "$venv" -path '*/lib/systemd/user/clavis-clipboard.service' -print -quit)
if [[ -n "$service" ]]; then
    mkdir -p "$HOME/.config/systemd/user"
    install -m 0644 "$service" "$HOME/.config/systemd/user/clavis-clipboard.service"
fi

printf '\n== keytop ==\n'
clone_at "$KEYTOP_REPO" "$KEYTOP_REV" "$CACHE/keytop"
rm -rf "$CACHE/keytop-build"
cmake -S "$CACHE/keytop" -B "$CACHE/keytop-build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON
cmake --build "$CACHE/keytop-build" -j "$JOBS"
ctest --test-dir "$CACHE/keytop-build" --output-on-failure
cmake --install "$CACHE/keytop-build" --prefix "$PREFIX"

printf '\n== wlogout (user-local) ==\n'
clone_at "$WLOGOUT_REPO" "$WLOGOUT_REV" "$CACHE/wlogout"
rm -rf "$CACHE/wlogout-build"
meson setup "$CACHE/wlogout-build" "$CACHE/wlogout" \
    --prefix "$PREFIX" --buildtype release \
    -Dman-pages=disabled \
    -Dbash-completions=false \
    -Dfish-completions=false \
    -Dzsh-completions=false
ninja -C "$CACHE/wlogout-build" -j "$JOBS"
meson install -C "$CACHE/wlogout-build"

printf '\n== Meteocons assets ==\n'
meteocons="$PREFIX/share/quickshell/clavis/assets/icons/weather/meteocons"
tmp_assets="$CACHE/meteocons-packages"
rm -rf "$tmp_assets" "$meteocons/svg" "$meteocons/lottie"
mkdir -p "$tmp_assets/svg" "$tmp_assets/lottie" "$meteocons/svg" "$meteocons/lottie"
svg_package=$(npm pack @meteocons/svg@0.1.0 --silent --pack-destination "$tmp_assets/svg")
lottie_package=$(npm pack @meteocons/lottie@0.1.0 --silent --pack-destination "$tmp_assets/lottie")
tar -xzf "$tmp_assets/svg/$svg_package" -C "$meteocons/svg" --strip-components=1
tar -xzf "$tmp_assets/lottie/$lottie_package" -C "$meteocons/lottie" --strip-components=1

mkdir -p "$HOME/.config/quickshell"
ln -sfn "$PREFIX/share/quickshell/clavis" "$HOME/.config/quickshell/clavis"

cat <<EOF

Clavis installed without elevated privileges.
  key:      $PREFIX/bin/key
  keytop:   $PREFIX/bin/keytop
  config:   $HOME/.config/quickshell/clavis
  QML root: $PREFIX/lib/qt6/qml

Start now with:
  PATH="$PREFIX/bin:\$PATH" QML_IMPORT_PATH="$PREFIX/lib/qt6/qml" key shell --daemon
EOF
