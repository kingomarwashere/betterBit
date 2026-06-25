#!/usr/bin/env bash
# Builds libtorrent from the webtorrent-cleanups branch (which bundles libdatachannel).
# Installs to ~/.local/betterbit-deps — pass as CMAKE_PREFIX_PATH when building betterBit.
#
# Usage:
#   ./scripts/build-webtorrent-deps.sh          # full build
#   ./scripts/build-webtorrent-deps.sh --clean  # wipe and rebuild

set -euo pipefail

PREFIX="${HOME}/.local/betterbit-deps"
BUILD_DIR="${HOME}/.local/betterbit-build"
JOBS=$(sysctl -n hw.logicalcpu 2>/dev/null || nproc)

# webtorrent-cleanups is the only libtorrent branch with the webtorrent cmake
# option; it bundles libdatachannel as a submodule so no separate build needed.
LIBTORRENT_BRANCH="webtorrent-cleanups"
LIBTORRENT_REPO="https://github.com/arvidn/libtorrent.git"

if [[ "${1:-}" == "--clean" ]]; then
    echo "==> Cleaning build dir"
    rm -rf "${BUILD_DIR}"
fi

mkdir -p "${BUILD_DIR}" "${PREFIX}"

# ── libtorrent-rasterbar (with bundled libdatachannel) ────────────────────────
echo ""
echo "==> Building libtorrent-rasterbar (${LIBTORRENT_BRANCH}) with webtorrent=ON"
LT_SRC="${BUILD_DIR}/libtorrent"
LT_BUILD="${BUILD_DIR}/libtorrent-build"

if [[ ! -d "${LT_SRC}/.git" ]]; then
    git clone --depth 1 --recurse-submodules --branch "${LIBTORRENT_BRANCH}" \
        "${LIBTORRENT_REPO}" "${LT_SRC}"
else
    git -C "${LT_SRC}" fetch origin "${LIBTORRENT_BRANCH}" && \
    git -C "${LT_SRC}" checkout "origin/${LIBTORRENT_BRANCH}" && \
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
echo "==> Done. libtorrent with WebTorrent support installed to ${PREFIX}"
echo ""
echo "Now build betterBit with:"
echo "  cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=${PREFIX} -DWEBTORRENT=ON"
echo "  cmake --build build --parallel"
