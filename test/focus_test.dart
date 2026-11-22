import 'package:cadence/core/focus.dart';
import 'package:cadence/core/models.dart';
import 'package:cadence/core/store.dart';
import 'package:cadence/services/focus_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('focus timer', () {
    late DateTime now;
    late AppStore store;
    late FocusTimer timer;

    setUp(() {
      now = DateTime(2026, 3, 2, 9);
      store = AppStore.memory(AppData()..settings.focusRounds = 2);
      timer = FocusTimer(clock: () => now, notify: false)..attach(store);
    });

    tearDown(() => timer.dispose());

    test('counts down from the focus length', () {
      expect(timer.idle, isTrue);
      expect(timer.remaining, const Duration(minutes: 25));
      timer.start();
      now = now.add(const Duration(minutes: 10));
      expect(timer.remaining, const Duration(minutes: 15));
      expect(timer.progress, closeTo(0.4, 0.001));
    });

    test('pausing keeps the time left', () {
      timer.start();
      now = now.add(const Duration(minutes: 5));
      timer.pause();
      now = now.add(const Duration(hours: 1));
      expect(timer.paused, isTrue);
      expect(timer.remaining, const Duration(minutes: 20));
      timer.start();
      now = now.add(const Duration(minutes: 1));
      expect(timer.remaining, const Duration(minutes: 19));
    });

    test('a finished session is logged and the break starts', () {
      timer.link('subject-1');
      timer.start();
      now = now.add(const Duration(minutes: 25));
      timer.check();
      expect(store.data.focusLog, hasLength(1));
      expect(store.data.focusLog.single.minutes, 25);
      expect(store.data.focusLog.single.subjectId, 'subject-1');
      expect(store.data.focusLog.single.start, DateTime(2026, 3, 2, 9));
      expect(timer.phase, FocusPhase.shortBreak);
      expect(timer.running, isTrue, reason: 'breaks start automatically by default');
    });

    test('a long break follows the last round, then the cycle restarts', () {
      void finish() {
        if (!timer.running) timer.start();
        now = now.add(timer.remaining);
        timer.check();
      }

      finish(); // focus 1
      finish(); // short break
      expect(timer.phase, FocusPhase.focus);
      expect(timer.round, 2);
      expect(timer.running, isFalse, reason: 'focus waits for the user after a break');
      finish(); // focus 2
      expect(timer.phase, FocusPhase.longBreak);
      finish(); // long break
      expect(timer.phase, FocusPhase.focus);
      expect(timer.round, 1);
      expect(store.data.focusLog, hasLength(2));
    });

    test('resetting part-way keeps the minutes already done', () {
      timer.start();
      now = now.add(const Duration(minutes: 12, seconds: 30));
      timer.reset();
      expect(store.data.focusLog.single.minutes, 12);
      expect(timer.idle, isTrue);
      expect(timer.remaining, const Duration(minutes: 25));
    });

    test('changing the length mid-session keeps the running phase', () {
      timer.start();
      now = now.add(const Duration(minutes: 5));
      store.settings.focusMinutes = 50;
      expect(timer.remaining, const Duration(minutes: 20));
      expect(timer.progress, closeTo(0.2, 0.001));
      now = now.add(const Duration(minutes: 20));
      timer.check();
      expect(store.data.focusLog.single.minutes, 25);
    });

    test('a session under a minute is not logged', () {
      timer.start();
      now = now.add(const Duration(seconds: 40));
      timer.reset();
      expect(store.data.focusLog, isEmpty);
    });

    test('the Do Not Disturb window only exists while focusing with the option on', () {
      timer.start();
      expect(timer.doNotDisturbWindow, isNull);
      store.settings.focusDoNotDisturb = true;
      expect(timer.doNotDisturbWindow?.end, DateTime(2026, 3, 2, 9, 25));
      timer.pause();
      expect(timer.doNotDisturbWindow, isNull);
    });
  });

  group('focus stats', () {
    final today = DateTime(2026, 3, 8);
    FocusSession at(int day, int minutes, [String? subject]) =>
        FocusSession(start: DateTime(2026, 3, day, 10), minutes: minutes, subjectId: subject);

    test('daily totals for the last week, oldest first', () {
      final log = [at(1, 99), at(2, 25), at(8, 25), at(8, 50)];
      expect(FocusStats.dailyMinutes(log, today), [25, 0, 0, 0, 0, 0, 75]);
    });

    test('streak counts back from today, or yesterday if today is empty', () {
      expect(FocusStats.streak([at(6, 25), at(7, 25), at(8, 25)], today), 3);
      expect(FocusStats.streak([at(5, 25), at(6, 25), at(7, 25)], today), 3);
      expect(FocusStats.streak([at(5, 25), at(7, 25)], today), 1);
      expect(FocusStats.streak([at(5, 25)], today), 0);
    });

    test('minutes per subject, largest first', () {
      final log = [at(7, 25, 'a'), at(7, 50, 'b'), at(8, 25, 'a'), at(1, 300, 'c'), at(8, 5)];
      final by = FocusStats.bySubject(log, DateTime(2026, 3, 2));
      expect(Map.fromEntries(by), {'a': 50, 'b': 50, null: 5});
      expect(by.last.key, isNull);
    });

    test('the focus log survives a save and load', () {
      final data = AppData(focusLog: [at(8, 25, 'a')]);
      final back = AppData.fromJson(data.toJson());
      expect(back.focusLog.single.minutes, 25);
      expect(back.focusLog.single.subjectId, 'a');
    });

    test('the log is capped', () {
      final store = AppStore.memory();
      for (var i = 0; i < maxFocusSessions + 5; i++) {
        store.data.focusLog.add(at(1, 1));
      }
      store.logFocus(at(8, 25));
      expect(store.data.focusLog.length, maxFocusSessions);
      expect(store.data.focusLog.last.minutes, 25);
    });
  });
}
