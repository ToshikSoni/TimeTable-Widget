import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Loops the alarm sound on desktop until dismissed. Stops by itself after
/// a few minutes so a forgotten alarm doesn't ring all day.
class AlarmPlayer {
  AlarmPlayer._();
  static final instance = AlarmPlayer._();

  AudioPlayer? _player;
  Timer? _timeout;

  Future<void> start() async {
    try {
      final p = _player ??= AudioPlayer();
      await p.setReleaseMode(ReleaseMode.loop);
      await p.play(AssetSource('sounds/cadence_alarm.wav'), volume: 0.9);
      _timeout?.cancel();
      _timeout = Timer(const Duration(minutes: 3), stop);
    } catch (e) {
      debugPrint('Alarm sound failed: $e');
    }
  }

  Future<void> chime() async {
    try {
      final p = AudioPlayer();
      await p.play(AssetSource('sounds/cadence_chime.wav'), volume: 0.8);
      p.onPlayerComplete.first.then((_) => p.dispose());
    } catch (e) {
      debugPrint('Chime failed: $e');
    }
  }

  Future<void> stop() async {
    _timeout?.cancel();
    try {
      await _player?.stop();
    } catch (_) {}
  }
}
