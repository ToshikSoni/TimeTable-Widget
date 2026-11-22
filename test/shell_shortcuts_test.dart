import 'package:cadence/core/models.dart';
import 'package:cadence/core/sample_data.dart';
import 'package:cadence/core/store.dart';
import 'package:cadence/ui/app_scope.dart';
import 'package:cadence/ui/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Clock clock;

  Future<void> pumpShell(WidgetTester tester) async {
    final tt = buildSampleTimetable();
    final store = AppStore.memory(AppData(timetables: [tt], activeTimetableId: tt.id));
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    clock = Clock();
    await tester.pumpWidget(
      AppScope(
        store: store,
        child: ClockScope(
          clock: clock,
          child: const MaterialApp(home: Shell()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    clock.dispose();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Ctrl+K opens search', (tester) async {
    await pumpShell(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Search classes, rooms, teachers, tasks…'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Ctrl+4 opens the focus timer on wide windows', (tester) async {
    await pumpShell(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Ready when you are'), findsOneWidget);
    await unmount(tester);
  });
}
