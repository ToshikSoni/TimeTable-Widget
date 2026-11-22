import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/focus.dart';
import '../core/models.dart';
import '../core/store.dart';
import 'alarm_player.dart';
import 'notifications.dart';

/// A Pomodoro-style focus timer: focus, short break, repeat, then a long
/// break.
///
/// The timer keeps wall-clock deadlines rather than counting ticks, so it
/// stays correct if the app is suspended, the laptop sleeps or the UI is
/// closed to the tray. Finished focus phases are added to the focus history.
class FocusTimer extends ChangeNotifier {
  FocusTimer({DateTime Function()? clock, this.notify = true}) : _clock = clock ?? DateTime.now;

  static final instance = FocusTimer();

  final DateTime Function() _clock;

  /// Whether to show notifications and play sounds (off in tests).
  final bool notify;

  AppStore? _store;
  Timer? _ticker;

  FocusPhase _phase = FocusPhase.focus;
  int _round = 1;
  DateTime? _endsAt;
  DateTime? _phaseStarted;

  /// Length of the phase in progress, fixed when it starts so changing the
  /// settings mid-session doesn't move the dial.
  Duration? _phaseLength;
  Duration? _remaining;
  String? subjectId;
  String? label;

  /// Called when anything about the timer changes that platform integrations
  /// (Do Not Disturb, tray) care about.
  VoidCallback? onStateChanged;

  FocusPhase get phase => _phase;

  /// 1-based focus round within the current cycle.
  int get round => _round;
  bool get running => _endsAt != null;
  bool get paused => _endsAt == null && _remaining != null;
  bool get idle => _endsAt == null && _remaining == null;
  DateTime? get endsAt => _endsAt;

  Settings get _settings => _store?.settings ?? Settings();
  int get rounds => _settings.focusRounds;
  Duration get total => _phaseLength ?? Duration(minutes: _settings.minutesFor(_phase));

  Duration get remaining {
    final end = _endsAt;
    if (end != null) {
      final left = end.difference(_clock());
      return left.isNegative ? Duration.zero : left;
    }
    return _remaining ?? total;
  }

  /// 0 at the start of a phase, 1 when it ends.
  double get progress {
    final t = total.inMilliseconds;
    if (t <= 0) return 0;
    return (1 - remaining.inMilliseconds / t).clamp(0.0, 1.0);
  }

  /// The window during which the phone should be silenced, if any.
  ({DateTime start, DateTime end})? get doNotDisturbWindow {
    final end = _endsAt;
    if (end == null || _phase != FocusPhase.focus || !_settings.focusDoNotDisturb) return null;
    return (start: _phaseStarted ?? _clock(), end: end);
  }

  void attach(AppStore store) => _store = store;

  /// Links the session to a subject (or none); kept for the next sessions.
  void link(String? subject) {
    subjectId = subject;
    notifyListeners();
  }

  void start() {
    if (running) return;
    final now = _clock();
    _phaseLength ??= total;
    final left = _remaining ?? total;
    _phaseStarted ??= now;
    _endsAt = now.add(left);
    _remaining = null;
    _startTicker();
    _scheduleEndNotification();
    _changed();
  }

  void pause() {
    if (!running) return;
    _remaining = remaining;
    _endsAt = null;
    _ticker?.cancel();
    if (notify) NotificationService.instance.cancelFocusEnd();
    _changed();
  }

  void toggle() => running ? pause() : start();

  /// Stops and returns to the start of a fresh focus phase. A focus session
  /// that ran for at least a minute is still recorded.
  void reset() {
    if (_phase == FocusPhase.focus) _logPartial();
    _ticker?.cancel();
    _endsAt = null;
    _remaining = null;
    _phaseStarted = null;
    _phaseLength = null;
    _phase = FocusPhase.focus;
    _round = 1;
    if (notify) NotificationService.instance.cancelFocusEnd();
    _changed();
  }

  /// Ends the current phase early and moves on to the next one.
  void skip() {
    if (_phase == FocusPhase.focus) _logPartial();
    _advance(autoStart: running);
  }

  /// Picks a phase directly (from the phase chips); stops the timer.
  void select(FocusPhase phase) {
    if (phase == _phase && idle) return;
    if (_phase == FocusPhase.focus) _logPartial();
    _ticker?.cancel();
    _phase = phase;
    _endsAt = null;
    _remaining = null;
    _phaseStarted = null;
    _phaseLength = null;
    if (notify) NotificationService.instance.cancelFocusEnd();
    _changed();
  }

  /// Re-checks the deadline, e.g. after the app resumes.
  void check() {
    if (running && !_clock().isBefore(_endsAt!)) _complete();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!running) return;
      if (!_clock().isBefore(_endsAt!)) {
        _complete();
      } else {
        notifyListeners();
      }
    });
  }

  void _complete() {
    final finished = _phase;
    if (finished == FocusPhase.focus) {
      final started = _phaseStarted ?? _endsAt!.subtract(total);
      _log(started, total.inMinutes);
    }
    final (title, body) = _finishedMessage(finished);
    if (notify) {
      NotificationService.instance.focusFinished(title, body);
      // Android plays the notification's own sound.
      if (kIsWeb || !Platform.isAndroid) AlarmPlayer.instance.chime();
    }
    _advance(autoStart: finished == FocusPhase.focus && _settings.focusAutoBreaks);
  }

  void _advance({required bool autoStart}) {
    _ticker?.cancel();
    if (_phase == FocusPhase.focus) {
      _phase = _round >= rounds ? FocusPhase.longBreak : FocusPhase.shortBreak;
    } else {
      _round = _phase == FocusPhase.longBreak ? 1 : _round + 1;
      _phase = FocusPhase.focus;
    }
    _endsAt = null;
    _remaining = null;
    _phaseStarted = null;
    _phaseLength = null;
    if (notify) NotificationService.instance.cancelFocusEnd();
    if (autoStart) {
      start();
    } else {
      _changed();
    }
  }

  (String, String) _finishedMessage(FocusPhase finished) {
    final s = _settings;
    if (finished == FocusPhase.focus) {
      final long = _round >= rounds;
      return (
        'Nice work — focus session done',
        long
            ? 'Take a longer break: ${s.longBreakMinutes} minutes.'
            : 'Time for a ${s.shortBreakMinutes}-minute break.',
      );
    }
    return ('Break’s over', 'Ready for another ${s.focusMinutes} minutes of focus?');
  }

  void _scheduleEndNotification() {
    final end = _endsAt;
    if (!notify || end == null) return;
    final (title, body) = _finishedMessage(_phase);
    NotificationService.instance.scheduleFocusEnd(end, title, body);
  }

  void _logPartial() {
    final started = _phaseStarted;
    if (started == null) return;
    final elapsed = total - remaining;
    if (elapsed.inMinutes >= 1) _log(started, elapsed.inMinutes);
  }

  void _log(DateTime start, int minutes) {
    if (minutes <= 0) return;
    _store?.logFocus(
      FocusSession(start: start, minutes: minutes, subjectId: subjectId, label: label),
    );
  }

  void _changed() {
    notifyListeners();
    onStateChanged?.call();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
