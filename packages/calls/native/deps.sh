#!/usr/bin/env bash
# Builds the static dependencies of libmgcalls for the macOS architecture of
# this machine: OpenSSL, Opus, rnnoise, mozjpeg, libvpx, openh264, FFmpeg
# (stage "deps") and tg_owt, Telegram's WebRTC (stage "tg_owt").
#
#   packages/calls/native/deps.sh [deps|tg_owt|all]
#
# The recipe follows tdesktop's Telegram/build/prepare/prepare.py at the pins
# in ../calls.json. CI caches both stages by these pins and this file.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

build_openssl() {
  log "OpenSSL $(pin openssl)"
  local version sha
  version=$(pin openssl)
  sha=$(pin openssl_sha256)
  curl -fsSL -o "$src/openssl.tar.gz" \
    "https://github.com/openssl/openssl/releases/download/openssl-$version/openssl-$version.tar.gz"
  echo "$sha  $src/openssl.tar.gz" | shasum -a 256 -c -
  tar -xzf "$src/openssl.tar.gz" -C "$src"
  (
    cd "$src/openssl-$version"
    ./Configure "$openssl_target" no-shared no-tests no-docs "$min" \
      --prefix="$prefix" --libdir=lib
    make -j"$jobs" build_libs
    make install_dev
  )
}

build_opus() {
  log "Opus $(pin opus)"
  checkout https://github.com/xiph/opus.git "$src/opus" "$(pin opus)"
  cmake -S "$src/opus" -B "$src/opus/build" "${cmake_common[@]}" \
    -DOPUS_BUILD_PROGRAMS=OFF -DOPUS_BUILD_TESTING=OFF
  cmake --build "$src/opus/build"
  cmake --install "$src/opus/build"
}

build_rnnoise() {
  log "rnnoise $(pin rnnoise)"
  checkout https://github.com/desktop-app/rnnoise.git "$src/rnnoise" "$(pin rnnoise)"
  cmake -S "$src/rnnoise" -B "$src/rnnoise/build" "${cmake_common[@]}"
  cmake --build "$src/rnnoise/build"
  mkdir -p "$prefix/lib" "$prefix/include"
  cp "$src/rnnoise/build/librnnoise.a" "$prefix/lib/"
  cp "$src/rnnoise/include/rnnoise.h" "$prefix/include/"
}

# mozjpeg's own GNUInstallDirs resolves a relative LIBDIR against the working
# directory, not the prefix, so it gets an absolute one.
build_mozjpeg() {
  log "mozjpeg $(pin mozjpeg)"
  checkout https://github.com/mozilla/mozjpeg.git "$src/mozjpeg" "$(pin mozjpeg)"
  cmake -S "$src/mozjpeg" -B "$src/mozjpeg/build" "${cmake_common[@]}" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_INSTALL_LIBDIR="$prefix/lib" \
    -DWITH_JPEG8=ON -DENABLE_SHARED=OFF -DPNG_SUPPORTED=OFF -DWITH_TURBOJPEG=OFF
  cmake --build "$src/mozjpeg/build"
  cmake --install "$src/mozjpeg/build"
}

build_libvpx() {
  log "libvpx $(pin libvpx)"
  checkout https://github.com/desktop-app/patches.git "$src/patches" "$(pin patches)"
  checkout https://github.com/webmproject/libvpx.git "$src/libvpx" "$(pin libvpx)"
  (
    cd "$src/libvpx"
    find ../patches/libvpx -type f -name '*.patch' -print0 | sort -z | xargs -0 git apply
    ./configure --prefix="$prefix" \
      --target="$vpx_target" \
      --disable-examples \
      --disable-unit-tests \
      --disable-tools \
      --disable-docs \
      --enable-vp8 \
      --enable-vp9 \
      --enable-webm-io \
      --enable-pic \
      --size-limit=4096x4096
    make -j"$jobs"
    make install
  )
}

build_openh264() {
  log "openh264 $(pin openh264)"
  checkout https://github.com/cisco/openh264.git "$src/openh264" "$(pin openh264)"
  meson setup "$src/openh264/build" "$src/openh264" \
    --prefix="$prefix" --libdir=lib \
    --default-library=static \
    --buildtype=minsize \
    -Dtests=disabled
  meson compile -C "$src/openh264/build"
  meson install -C "$src/openh264/build"
}

# Only what tgcalls and tg_owt use: H.264/H.265/VP8/VP9 and Opus decoding
# for group call streams and WebRTC's software H.264 decoder. The media
# player in the app has its own FFmpeg; this one never leaves libmgcalls.
build_ffmpeg() {
  log "FFmpeg $(pin ffmpeg)"
  checkout https://github.com/FFmpeg/FFmpeg.git "$src/ffmpeg" "$(pin ffmpeg)"
  (
    cd "$src/ffmpeg"
    ./configure --prefix="$prefix" \
      --arch="$arch" \
      --extra-cflags="$min -DCONFIG_SAFE_BITSTREAM_READER=1" \
      --extra-ldflags="$min" \
      --disable-autodetect \
      --disable-programs \
      --disable-doc \
      --disable-network \
      --disable-avdevice \
      --disable-avfilter \
      --disable-everything \
      --enable-pic \
      --enable-pthreads \
      --enable-videotoolbox \
      --enable-protocol=file \
      --enable-hwaccel=h264_videotoolbox \
      --enable-hwaccel=hevc_videotoolbox \
      --enable-decoder=h264 \
      --enable-decoder=hevc \
      --enable-decoder=vp8 \
      --enable-decoder=vp9 \
      --enable-decoder=opus \
      --enable-decoder=aac \
      --enable-parser=h264 \
      --enable-parser=hevc \
      --enable-parser=vp8 \
      --enable-parser=vp9 \
      --enable-parser=opus \
      --enable-parser=aac \
      --enable-demuxer=ogg \
      --enable-demuxer=mov \
      --enable-demuxer=matroska \
      --enable-demuxer=h264 \
      --enable-demuxer=hevc
    make -j"$jobs"
    make install
  )
}

stage_deps() {
  rm -rf "$prefix" "$src"
  mkdir -p "$prefix" "$src"
  build_openssl
  build_opus
  build_rnnoise
  build_mozjpeg
  build_libvpx
  build_openh264
  build_ffmpeg
  rm -rf "$src"
}

# WebRTC with Telegram's patches. The audio backends are on: we use WebRTC's
# own CoreAudio device module (docs/calls.md, "Audio").
stage_tg_owt() {
  local dir="$work/tg_owt"
  log "tg_owt $(pin tg_owt)"
  checkout https://github.com/desktop-app/tg_owt.git "$dir" "$(pin tg_owt)"
  git -C "$dir" submodule update -q --init --recursive --depth 1 \
    || git -C "$dir" submodule update -q --init --recursive
  cmake -S "$dir" -B "$dir/out" "${cmake_common[@]}" \
    -DTG_OWT_SPECIAL_TARGET=mac \
    -DTG_OWT_BUILD_AUDIO_BACKENDS=ON \
    -DTG_OWT_LIBJPEG_INCLUDE_PATH="$prefix/include" \
    -DTG_OWT_OPENSSL_INCLUDE_PATH="$prefix/include" \
    -DTG_OWT_OPUS_INCLUDE_PATH="$prefix/include/opus" \
    -DTG_OWT_LIBVPX_INCLUDE_PATH="$prefix/include" \
    -DTG_OWT_OPENH264_INCLUDE_PATH="$prefix/include" \
    -DTG_OWT_FFMPEG_INCLUDE_PATH="$prefix/include"
  cmake --build "$dir/out" --target tg_owt -j"$jobs"
  # Keep the headers and the archive; the objects are not needed any more.
  find "$dir/out" -name '*.o' -delete
  rm -rf "$dir/.git"
}

case "${1:-all}" in
  deps) stage_deps ;;
  tg_owt) stage_tg_owt ;;
  all) stage_deps; stage_tg_owt ;;
  *) echo "usage: $0 [deps|tg_owt|all]" >&2; exit 2 ;;
esac
