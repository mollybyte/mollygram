#!/usr/bin/env bash
# Shared settings for deps.sh and build.sh. Sourced, not run.

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pins="$here/../calls.json"
pin() { jq -r ".$1" "$pins"; }

arch="$(uname -m)"
case "$arch" in
  arm64) openssl_target=darwin64-arm64-cc vpx_target=arm64-darwin20-gcc ;;
  x86_64) openssl_target=darwin64-x86_64-cc vpx_target=x86_64-darwin20-gcc ;;
  *) echo "unsupported architecture: $arch" >&2; exit 1 ;;
esac

export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-11.0}"
work="${MGCALLS_WORK:-$here/.build/$arch}"
prefix="$work/prefix"
src="$work/src"
jobs="$(sysctl -n hw.ncpu)"
min="-mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"

# clang reads MACOSX_DEPLOYMENT_TARGET itself, so configure scripts need no
# extra flags for it.
export PKG_CONFIG_PATH="$prefix/lib/pkgconfig"

cmake_common=(
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_OSX_ARCHITECTURES="$arch"
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET"
  -DCMAKE_INSTALL_PREFIX="$prefix"
  -DCMAKE_INSTALL_LIBDIR=lib
  -DCMAKE_PREFIX_PATH="$prefix"
)

log() { printf '\n==> %s\n' "$*"; }

# Shallow checkout of one commit or tag into $2.
checkout() {
  local url=$1 dir=$2 ref=$3
  rm -rf "$dir"
  git init -q "$dir"
  git -C "$dir" remote add origin "$url"
  git -C "$dir" fetch -q --depth 1 origin "$ref"
  git -C "$dir" checkout -q FETCH_HEAD
}

