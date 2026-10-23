#!/usr/bin/env bash
# Build an RPM (Fedora, RHEL/Alma/Rocky, openSUSE) from a Flutter Linux
# release bundle.
#
# Usage: build_rpm.sh <version> <bundle_dir> <out_dir>
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <version> <bundle_dir> <out_dir>" >&2
  exit 64
fi

VERSION="${1#v}"
BUNDLE_DIR="$(cd "$2" && pwd)"
OUT_DIR="$3"
APP_ID="io.github.toshiksoni.cadence"
ICON_SIZES=(48 64 128 256 512)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ ! -x "$BUNDLE_DIR/cadence" ]; then
  echo "error: $BUNDLE_DIR/cadence not found or not executable" >&2
  exit 1
fi

# RPM versions can't contain "-"; 1.2.0-beta.1 becomes 1.2.0~beta.1.
RPM_VERSION="${VERSION//-/\~}"

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
TOP="$(mktemp -d)"
trap 'rm -rf "$TOP"' EXIT
mkdir -p "$TOP"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

icon_lines=""
for size in "${ICON_SIZES[@]}"; do
  if [ -f "$REPO_ROOT/assets/branding/icon-$size.png" ]; then
    icon_lines+="install -Dm0644 \"$REPO_ROOT/assets/branding/icon-$size.png\" \"%{buildroot}/usr/share/icons/hicolor/${size}x${size}/apps/$APP_ID.png\""$'\n'
  fi
done

cat > "$TOP/SPECS/cadence.spec" <<SPEC
Name:           cadence
Version:        $RPM_VERSION
Release:        1
Summary:        Timetable and daily planner with widgets, reminders and alarms
License:        MIT
URL:            https://github.com/ToshikSoni/TimeTable-Widget
ExclusiveArch:  x86_64
# The bundle ships its own Flutter engine; don't derive requirements from it.
AutoReqProv:    no
Requires:       gtk3
Requires:       (gstreamer1 or gstreamer)
Requires:       (gstreamer1-plugins-base or gstreamer-plugins-base)
Recommends:     (gstreamer1-plugins-good or gstreamer-plugins-good)

%global debug_package %{nil}
%global __os_install_post %{nil}

%description
Cadence keeps your class timetable or daily routine one glance away, with
week and day views, a desktop widget, reminders, alarms and Do Not Disturb
blocks, lab groups and electives, attendance tracking, tasks and exams. It
works fully offline and stores all data locally.

%install
install -d %{buildroot}/opt/cadence
cp -a "$BUNDLE_DIR/." %{buildroot}/opt/cadence/
chmod 0755 %{buildroot}/opt/cadence/cadence
install -d %{buildroot}/usr/bin
ln -s /opt/cadence/cadence %{buildroot}/usr/bin/cadence
install -Dm0644 "$SCRIPT_DIR/$APP_ID.desktop" %{buildroot}/usr/share/applications/$APP_ID.desktop
install -Dm0644 "$SCRIPT_DIR/$APP_ID.metainfo.xml" %{buildroot}/usr/share/metainfo/$APP_ID.metainfo.xml
install -Dm0644 "$REPO_ROOT/LICENSE" %{buildroot}/usr/share/licenses/cadence/LICENSE
$icon_lines
%files
/opt/cadence
/usr/bin/cadence
/usr/share/applications/$APP_ID.desktop
/usr/share/metainfo/$APP_ID.metainfo.xml
/usr/share/icons/hicolor/*/apps/$APP_ID.png
%license /usr/share/licenses/cadence/LICENSE
SPEC

rpmbuild --define "_topdir $TOP" --define "_build_id_links none" -bb "$TOP/SPECS/cadence.spec"
cp "$TOP"/RPMS/x86_64/cadence-*.rpm "$OUT_DIR/cadence-$VERSION-1.x86_64.rpm"
echo "Built $OUT_DIR/cadence-$VERSION-1.x86_64.rpm"
