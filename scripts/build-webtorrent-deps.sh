#!/usr/bin/env bash
# Builds libtorrent v2.1.0-rc2 with WebTorrent (WebRTC) support.
# libdatachannel is bundled as a submodule — no separate build needed.
# Installs to ~/.local/betterbit-deps — pass as CMAKE_PREFIX_PATH when building betterBit.
#
# Usage:
#   ./scripts/build-webtorrent-deps.sh          # full build
#   ./scripts/build-webtorrent-deps.sh --clean  # wipe and rebuild

set -euo pipefail

PREFIX="${HOME}/.local/betterbit-deps"
BUILD_DIR="${HOME}/.local/betterbit-build"
JOBS=$(sysctl -n hw.logicalcpu 2>/dev/null || nproc)

# v2.1.0-rc2: first release with complete, stable WebTorrent support.
# libdatachannel is bundled as a submodule — no separate build step needed.
LIBTORRENT_TAG="v2.1.0-rc2"
LIBTORRENT_REPO="https://github.com/arvidn/libtorrent.git"

if [[ "${1:-}" == "--clean" ]]; then
    echo "==> Cleaning build dir"
    rm -rf "${BUILD_DIR}"
fi

mkdir -p "${BUILD_DIR}" "${PREFIX}"

# ── libtorrent-rasterbar ──────────────────────────────────────────────────────
echo ""
echo "==> Building libtorrent-rasterbar ${LIBTORRENT_TAG} with webtorrent=ON"
LT_SRC="${BUILD_DIR}/libtorrent"
LT_BUILD="${BUILD_DIR}/libtorrent-build"

if [[ ! -d "${LT_SRC}/.git" ]]; then
    git clone --depth 1 --recurse-submodules --branch "${LIBTORRENT_TAG}" \
        "${LIBTORRENT_REPO}" "${LT_SRC}"
else
    git -C "${LT_SRC}" fetch origin "refs/tags/${LIBTORRENT_TAG}:refs/tags/${LIBTORRENT_TAG}" && \
    git -C "${LT_SRC}" checkout "${LIBTORRENT_TAG}" && \
    git -C "${LT_SRC}" submodule update --init --recursive
fi

rm -rf "${LT_BUILD}"

cmake -S "${LT_SRC}" -B "${LT_BUILD}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -Dwebtorrent=ON \
    -Ddeprecated-functions=OFF \
    -Dpython-bindings=OFF \
    -Dbuild_tests=OFF \
    -Dbuild_examples=OFF \
    -Dbuild_tools=OFF \
    -DBUILD_SHARED_LIBS=ON

cmake --build "${LT_BUILD}" --parallel "${JOBS}"
cmake --install "${LT_BUILD}"

echo ""
echo "==> Done. libtorrent ${LIBTORRENT_TAG} with WebTorrent installed to ${PREFIX}"
echo ""
echo "Now build betterBit with:"
echo "  cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=${PREFIX}"
echo "  cmake --build build --parallel"
