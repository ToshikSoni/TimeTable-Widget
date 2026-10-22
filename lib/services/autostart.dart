import 'dart:io';

/// Starts Cadence when the user signs in.
///
/// Windows: a value named `Cadence` under
/// `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` (the installer and
/// uninstaller use the same name). Linux: an XDG autostart entry in
/// `~/.config/autostart`.
class Autostart {
  Autostart({required this.executable, this.args = const ['--hidden']});

  final String executable;
  final List<String> args;

  static const _name = 'Cadence';
  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _desktopFile = 'io.github.toshiksoni.cadence.desktop';

  String get _command => ['"$executable"', ...args].join(' ');

  File get _linuxEntry {
    final config =
        Platform.environment['XDG_CONFIG_HOME'] ?? '${Platform.environment['HOME']}/.config';
    return File('$config/autostart/$_desktopFile');
  }

  Future<bool> isEnabled() async {
    if (Platform.isWindows) {
      final r = await Process.run('reg', ['query', _runKey, '/v', _name]);
      return r.exitCode == 0;
    }
    if (Platform.isLinux) return _linuxEntry.exists();
    return false;
  }

  Future<void> enable() async {
    if (Platform.isWindows) {
      final r = await Process.run('reg', [
        'add',
        _runKey,
        '/v',
        _name,
        '/t',
        'REG_SZ',
        '/d',
        _command,
        '/f',
      ]);
      if (r.exitCode != 0) throw ProcessException('reg', const [], '${r.stderr}', r.exitCode);
    } else if (Platform.isLinux) {
      final entry = _linuxEntry;
      await entry.parent.create(recursive: true);
      await entry.writeAsString('''
[Desktop Entry]
Type=Application
Name=Cadence
Comment=Timetable reminders and desktop widget
Exec=$_command
Icon=io.github.toshiksoni.cadence
Terminal=false
X-GNOME-Autostart-enabled=true
''');
    }
  }

  Future<void> disable() async {
    if (Platform.isWindows) {
      await Process.run('reg', ['delete', _runKey, '/v', _name, '/f']);
    } else if (Platform.isLinux) {
      final entry = _linuxEntry;
      if (await entry.exists()) await entry.delete();
    }
  }
}
