# Contributing to Cadence

Thanks for taking the time to help out. Bug reports, fixes, features and docs
improvements are all welcome. For anything bigger than a small fix, please open
an issue or a [discussion](https://github.com/ToshikSoni/TimeTable-Widget/discussions)
first so we can agree on the approach before you spend time on it.

By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
Security problems go through [SECURITY.md](SECURITY.md), not public issues.

## Development setup

You need **Flutter 3.47.7** (stable). CI pins this exact version, so using the
same one avoids formatter and analyzer surprises.

```sh
flutter --version        # should report 3.47.7, channel stable
flutter pub get
```

### Linux

```sh
sudo apt-get update
sudo apt-get install -y clang cmake pkg-config ninja-build \
  libgtk-3-dev libx11-dev libxi-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
flutter run -d linux
```

On other distributions, install the equivalent GTK 3, X11 and GStreamer
development packages.

### Windows

Install **Visual Studio 2022** with the **Desktop development with C++**
workload (the Build Tools edition is enough), then:

```sh
flutter run -d windows
```

### Android

Install the Android SDK (Android Studio is the easiest way) and a JDK 17, accept
the licences with `flutter doctor --android-licenses`, then plug in a device or
start an emulator:

```sh
flutter devices
flutter run -d <device-id>
```

The home-screen widgets only update on a real launcher, so test them on a device
or a full emulator image rather than relying on hot reload.

`flutter doctor` will tell you if anything is still missing.

## Project layout

| Path | What lives there |
| --- | --- |
| `lib/core/` | Models and the schedule engine (weeks, overrides, groups, electives) |
| `lib/services/` | Notifications and alarms, desktop integration (tray, autostart, widget window), home-screen widget sync |
| `lib/ui/` | Screens and reusable widgets |
| `android/app/src/main/kotlin/io/github/toshiksoni/cadence/widget/` | Android home-screen widgets |
| `test/` | Unit and widget tests |
| `packaging/` | Linux desktop entry, AppStream metadata, `.deb`/AppImage scripts and the Windows installer |
| `.github/workflows/` | CI and release builds |

## Code style

- Format with `dart format lib test`. CI fails on unformatted code.
- `flutter analyze` must be clean, with no new warnings or infos.
- Logic changes in `lib/core/` (especially the schedule engine) need tests in
  `test/`. Things like day overrides, lab groups and week boundaries are easy to
  break, so cover the edge cases you touch.
- Keep UI changes consistent across light and dark themes, and check desktop
  and phone widths.
- Cadence is offline by design. Please don't add analytics, network calls or
  dependencies that phone home.

Before pushing:

```sh
dart format lib test
flutter analyze
flutter test
```

## Commit messages

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<optional scope>): <short summary>
```

Common types: `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`,
`chore`. Examples:

```
feat(widget): show the next class on the Android 4x2 widget
fix(schedule): apply Saturday overrides before lab group filtering
docs: add Fedora build dependencies
```

Keep the summary under about 72 characters and use the body to explain *why*
when it isn't obvious. Mark breaking changes (for example, a backup format
change) with `!` after the type and a `BREAKING CHANGE:` footer.

## Pull requests

- Branch off `main` and keep each PR focused on one thing.
- Fill in the PR template, including which platforms you tested on.
- Add screenshots for visible UI changes.
- Add an entry under `## [Unreleased]` in `CHANGELOG.md` for user-facing changes.

## Cutting a release

Maintainers only:

1. Bump `version` in `pubspec.yaml`, e.g. `1.2.0+5`. Always increase the
   number after `+`; Android uses it as the version code and won't install an
   update with a lower one.
2. In `CHANGELOG.md`, rename `## [Unreleased]` to `## [1.2.0] - YYYY-MM-DD` and
   start a fresh `Unreleased` section. The release workflow uses this section as
   the release notes.
3. Commit (`chore(release): 1.2.0`), then tag and push:

   ```sh
   git tag v1.2.0
   git push origin main v1.2.0
   ```

4. The **Release** workflow builds the Windows installer and portable zip, the
   Linux tarball, `.deb` and AppImage, and the Android APKs, then publishes them
   with a `SHA256SUMS.txt` to a GitHub Release.

Android release signing uses the repository secrets `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`. If
they're missing, the APKs are signed with a debug key and the workflow prints a
warning.

## Translations

Cadence is English-only for now. Localisation support is planned; once the
strings are moved into ARB files this section will explain how to add a
language. If you'd like to help with that, say so in Discussions.

## License

Cadence is released under the [MIT License](LICENSE). By contributing, you agree
that your contributions are licensed under the same terms.
