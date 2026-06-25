#!/usr/bin/env bash
# Builds libdatachannel + libtorrent with WebTorrent (WebRTC) support.
# Installs to ~/.local/betterbit-deps — pass that as CMAKE_PREFIX_PATH when building betterBit.
#
# Usage:
#   ./scripts/build-webtorrent-deps.sh          # full build
#   ./scripts/build-webtorrent-deps.sh --clean  # wipe and rebuild

set -euo pipefail

PREFIX="${HOME}/.local/betterbit-deps"
BUILD_DIR="${HOME}/.local/betterbit-build"
JOBS=$(sysctl -n hw.logicalcpu 2>/dev/null || nproc)

LIBDATACHANNEL_TAG="v0.21.2"
LIBTORRENT_TAG="v2.0.13"          # RC_2_0 branch once a webtorrent-capable release lands
LIBTORRENT_REPO="https://github.com/arvidn/libtorrent.git"
LIBDATACHANNEL_REPO="https://github.com/paullouisageneau/libdatachannel.git"

if [[ "${1:-}" == "--clean" ]]; then
    echo "==> Cleaning build dir"
    rm -rf "${BUILD_DIR}"
fi

mkdir -p "${BUILD_DIR}" "${PREFIX}"

# ── libdatachannel ────────────────────────────────────────────────────────────
echo ""
echo "==> Building libdatachannel ${LIBDATACHANNEL_TAG}"
DC_SRC="${BUILD_DIR}/libdatachannel"
DC_BUILD="${BUILD_DIR}/libdatachannel-build"

if [[ ! -d "${DC_SRC}/.git" ]]; then
    git clone --depth 1 --recurse-submodules --branch "${LIBDATACHANNEL_TAG}" \
        "${LIBDATACHANNEL_REPO}" "${DC_SRC}"
fi

cmake -S "${DC_SRC}" -B "${DC_BUILD}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DNO_MEDIA=ON \
    -DNO_EXAMPLES=ON \
    -DNO_TESTS=ON \
    -DUSE_SYSTEM_SRTP=OFF

cmake --build "${DC_BUILD}" --parallel "${JOBS}"
cmake --install "${DC_BUILD}"

echo "==> libdatachannel installed to ${PREFIX}"

# ── libtorrent-rasterbar ──────────────────────────────────────────────────────
echo ""
echo "==> Building libtorrent-rasterbar ${LIBTORRENT_TAG} with webtorrent=ON"
LT_SRC="${BUILD_DIR}/libtorrent"
LT_BUILD="${BUILD_DIR}/libtorrent-build"

if [[ ! -d "${LT_SRC}/.git" ]]; then
    git clone --depth 1 --recurse-submodules --branch "${LIBTORRENT_TAG}" \
        "${LIBTORRENT_REPO}" "${LT_SRC}"
fi

cmake -S "${LT_SRC}" -B "${LT_BUILD}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DCMAKE_PREFIX_PATH="${PREFIX}" \
    -Dwebtorrent=ON \
    -Ddeprecated-functions=OFF \
    -Dpython-bindings=OFF \
    -Dtests=OFF \
    -Dexamples=OFF \
    -DBUILD_SHARED_LIBS=ON

cmake --build "${LT_BUILD}" --parallel "${JOBS}"
cmake --install "${LT_BUILD}"

echo ""
echo "==> Done. libtorrent with WebTorrent support installed to ${PREFIX}"
echo ""
echo "Now build betterBit with:"
echo "  cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=${PREFIX} -DWEBTORRENT=ON"
echo "  cmake --build build --parallel"
