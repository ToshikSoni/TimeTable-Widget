#!/usr/bin/env bash
# Build an AppImage from a Flutter Linux release bundle.
#
# Usage: build_appimage.sh <version> <bundle_dir> <out_dir>
#
# Needs appimagetool. Set APPIMAGETOOL to its path, otherwise it is looked up
# on PATH. It is run with --appimage-extract-and-run so FUSE isn't required.
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <version> <bundle_dir> <out_dir>" >&2
  exit 64
fi

VERSION="${1#v}"
BUNDLE_DIR="$2"
OUT_DIR="$3"

APP_ID="io.github.toshiksoni.cadence"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APPIMAGETOOL="${APPIMAGETOOL:-$(command -v appimagetool || true)}"

if [ -z "$APPIMAGETOOL" ] || [ ! -x "$APPIMAGETOOL" ]; then
  echo "error: appimagetool not found (set APPIMAGETOOL=/path/to/appimagetool)" >&2
  exit 1
fi
if [ ! -x "$BUNDLE_DIR/cadence" ]; then
  echo "error: $BUNDLE_DIR/cadence not found or not executable" >&2
  exit 1
fi

ICON="$REPO_ROOT/assets/branding/icon-256.png"
if [ ! -f "$ICON" ]; then
  echo "error: $ICON is required for the AppImage" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
APPDIR="$WORK/Cadence.AppDir"

install -d "$APPDIR/usr/bin"
cp -a "$BUNDLE_DIR/." "$APPDIR/usr/bin/"

cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/cadence" "$@"
APPRUN
chmod 0755 "$APPDIR/AppRun"

install -m0644 "$SCRIPT_DIR/$APP_ID.desktop" "$APPDIR/$APP_ID.desktop"
install -Dm0644 "$SCRIPT_DIR/$APP_ID.desktop" "$APPDIR/usr/share/applications/$APP_ID.desktop"
install -Dm0644 "$SCRIPT_DIR/$APP_ID.metainfo.xml" "$APPDIR/usr/share/metainfo/$APP_ID.metainfo.xml"
install -m0644 "$ICON" "$APPDIR/$APP_ID.png"
install -Dm0644 "$ICON" "$APPDIR/usr/share/icons/hicolor/256x256/apps/$APP_ID.png"
ln -s "$APP_ID.png" "$APPDIR/.DirIcon"

OUT_FILE="$OUT_DIR/Cadence-${VERSION}-x86_64.AppImage"
ARCH=x86_64 VERSION="$VERSION" \
  "$APPIMAGETOOL" --appimage-extract-and-run --no-appstream "$APPDIR" "$OUT_FILE"
chmod 0755 "$OUT_FILE"
echo "Built $OUT_FILE"
