#!/bin/sh
# Copies libtdjson into Mollygram.app/Contents/Frameworks and signs it with the
# app's identity. The library comes from TDJSON_PATH when set, otherwise from
# the tdlib-<version>-<commit> release built by .github/workflows/tdlib.yml,
# downloaded once into packages/tdlib/native/macos (ignored by git).
set -eu

repo_root="$SRCROOT/../../.."
pin="$repo_root/packages/tdlib/tdlib.json"
version=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$pin")
commit=$(sed -n 's/.*"commit": *"\([^"]*\)".*/\1/p' "$pin")
short=$(printf '%s' "$commit" | cut -c1-7)
cache="$repo_root/packages/tdlib/native/macos/$version-$short"
library="${TDJSON_PATH:-$cache/libtdjson.dylib}"

if [ ! -f "$library" ]; then
  base="https://github.com/mollybyte/mollygram/releases/download/tdlib-$version-$short"
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  echo "Downloading libtdjson $version ($short)"
  curl -fsSL -o "$tmp/libtdjson-macos-universal.zip" "$base/libtdjson-macos-universal.zip"
  curl -fsSL -o "$tmp/libtdjson-macos-universal.zip.sha256" "$base/libtdjson-macos-universal.zip.sha256"
  (cd "$tmp" && shasum -a 256 -c libtdjson-macos-universal.zip.sha256)
  mkdir -p "$cache"
  unzip -o -q "$tmp/libtdjson-macos-universal.zip" -d "$cache"
  library="$cache/libtdjson.dylib"
fi

destination="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"
mkdir -p "$destination"
cp -f "$library" "$destination/libtdjson.dylib"
codesign --force --timestamp=none \
  --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" \
  "$destination/libtdjson.dylib"
