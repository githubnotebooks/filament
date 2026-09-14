#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Linux desktop build for environments without a static libc++:
# force clang + libstdc++ (Filament's default of USE_STATIC_LIBCXX=ON needs
# libc++.a/libc++abi.a, which Nix-provided clang wrappers don't provide).
export CC=clang
export CXX=clang++

USAGE="Usage: linux_build.sh [-t] [-d] [debug|release] [target ...]
  -t  enable fgviewer
  -d  enable matdbg
Build type defaults to debug. Targets are passed to ninja (default: all)."

ENABLE_FGVIEWER=OFF
ENABLE_MATDBG=OFF
BUILD_TYPE=debug
TARGETS=()

while [ $# -gt 0 ]; do
    case "$1" in
        -t) ENABLE_FGVIEWER=ON ;;
        -d) ENABLE_MATDBG=ON ;;
        -h) echo "${USAGE}"; exit 0 ;;
        debug|release) BUILD_TYPE="$1" ;;
        -*) echo "Unknown option: $1"; echo "${USAGE}"; exit 1 ;;
        *) TARGETS+=("$1") ;;
    esac
    shift
done

BUILD_DIR="out/cmake-${BUILD_TYPE}"
mkdir -p "${BUILD_DIR}"

cmake -G Ninja -B "${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE="$(echo "${BUILD_TYPE}" | sed 's/^./\U&/')" \
    -DUSE_STATIC_LIBCXX=OFF \
    -DFILAMENT_ENABLE_FGVIEWER="${ENABLE_FGVIEWER}" \
    -DFILAMENT_ENABLE_MATDBG="${ENABLE_MATDBG}"

cmake --build "${BUILD_DIR}" ${TARGETS[@]+"--target" "${TARGETS[@]}"}

ln -sf "${BUILD_DIR}/compile_commands.json" compile_commands.json
