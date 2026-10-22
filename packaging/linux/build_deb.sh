#!/usr/bin/env bash
# Build a Debian package from a Flutter Linux release bundle.
#
# Usage: build_deb.sh <version> <bundle_dir> <out_dir>
#   version     e.g. 1.2.0 (a leading "v" is stripped)
#   bundle_dir  build/linux/x64/release/bundle
#   out_dir     where cadence_<version>_amd64.deb is written
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <version> <bundle_dir> <out_dir>" >&2
  exit 64
fi

VERSION="${1#v}"
BUNDLE_DIR="$2"
OUT_DIR="$3"

APP_ID="io.github.toshiksoni.cadence"
PKG_NAME="cadence"
ARCH="amd64"
ICON_SIZES=(48 64 128 256 512)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ ! -x "$BUNDLE_DIR/cadence" ]; then
  echo "error: $BUNDLE_DIR/cadence not found or not executable" >&2
  exit 1
fi

# Debian versions can't contain "-" in the upstream part without a revision,
# so turn pre-release suffixes (1.2.0-beta.1) into 1.2.0~beta.1.
DEB_VERSION="${VERSION/-/\~}"

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PKG="$WORK/pkg"

# Application bundle
install -d "$PKG/opt/cadence"
cp -a "$BUNDLE_DIR/." "$PKG/opt/cadence/"
chmod 0755 "$PKG/opt/cadence/cadence"

install -d "$PKG/usr/bin"
ln -s /opt/cadence/cadence "$PKG/usr/bin/cadence"

# Desktop integration
install -Dm0644 "$SCRIPT_DIR/$APP_ID.desktop" \
  "$PKG/usr/share/applications/$APP_ID.desktop"
install -Dm0644 "$SCRIPT_DIR/$APP_ID.metainfo.xml" \
  "$PKG/usr/share/metainfo/$APP_ID.metainfo.xml"

for size in "${ICON_SIZES[@]}"; do
  icon="$REPO_ROOT/assets/branding/icon-$size.png"
  if [ -f "$icon" ]; then
    install -Dm0644 "$icon" \
      "$PKG/usr/share/icons/hicolor/${size}x${size}/apps/$APP_ID.png"
  else
    echo "warning: $icon missing, skipping ${size}px icon" >&2
  fi
done

if [ -f "$REPO_ROOT/LICENSE" ]; then
  install -Dm0644 "$REPO_ROOT/LICENSE" "$PKG/usr/share/doc/$PKG_NAME/copyright"
fi

# Normalise permissions: directories 755, files 644 unless already executable.
find "$PKG" -type d -exec chmod 0755 {} +
find "$PKG" -type f ! -perm -u+x -exec chmod 0644 {} +
find "$PKG" -type f -perm -u+x -exec chmod 0755 {} +

INSTALLED_SIZE="$(du -sk --apparent-size "$PKG" | cut -f1)"

install -d "$PKG/DEBIAN"
cat > "$PKG/DEBIAN/control" <<CONTROL
Package: $PKG_NAME
Version: $DEB_VERSION
Architecture: $ARCH
Maintainer: Toshik Soni
Installed-Size: $INSTALLED_SIZE
Depends: libgtk-3-0, libgstreamer1.0-0, libgstreamer-plugins-base1.0-0, gstreamer1.0-plugins-good
Section: utils
Priority: optional
Homepage: https://github.com/ToshikSoni/TimeTable-Widget
Description: Class timetable with widgets, reminders and alarms
 Cadence keeps your class timetable one glance away, with week and day
 views, a desktop widget, reminders and alarms, lab groups and electives,
 attendance tracking, tasks and exams. It works fully offline and stores
 all data locally.
CONTROL
chmod 0644 "$PKG/DEBIAN/control"

cat > "$PKG/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q /usr/share/applications || true
  command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
exit 0
POSTINST
cp "$PKG/DEBIAN/postinst" "$PKG/DEBIAN/postrm"
sed -i 's/= "configure"/= "remove"/' "$PKG/DEBIAN/postrm"
chmod 0755 "$PKG/DEBIAN/postinst" "$PKG/DEBIAN/postrm"

OUT_FILE="$OUT_DIR/${PKG_NAME}_${VERSION}_${ARCH}.deb"
dpkg-deb --root-owner-group -Zxz --build "$PKG" "$OUT_FILE"
echo "Built $OUT_FILE"
