#!/usr/bin/env bash
# Builds libmgcalls.dylib (tgcalls + tg_owt + codecs, all static, exporting
# only the mg_call* C API) for the macOS architecture of this machine. Run
# deps.sh first.
#
#   packages/calls/native/deps.sh && packages/calls/native/build.sh
#
# Requires: Xcode command line tools, cmake, ninja, meson, nasm, jq.
#
# Environment:
#   MGCALLS_WORK              work directory (default: native/.build/<arch>)
#   MACOSX_DEPLOYMENT_TARGET  minimum macOS (default: 11.0, same as TDLib)

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

stage_mgcalls() {
  local tgcalls="$work/tgcalls" build="$work/mgcalls"
  log "tgcalls $(pin tgcalls) and libmgcalls"
  checkout https://github.com/TelegramMessenger/tgcalls.git "$tgcalls" "$(pin tgcalls)"
  rm -rf "$build"
  cmake -S "$here" -B "$build" "${cmake_common[@]}" \
    -DMGCALLS_TGCALLS_DIR="$tgcalls" \
    -DMGCALLS_TG_OWT_DIR="$work/tg_owt" \
    -DMGCALLS_DEPS_PREFIX="$prefix"
  cmake --build "$build" -j"$jobs"
  mkdir -p "$work/out"
  cp "$build/libmgcalls.dylib" "$work/out/libmgcalls.dylib"
  strip -x "$work/out/libmgcalls.dylib"
  echo "built $work/out/libmgcalls.dylib"
}

stage_mgcalls
