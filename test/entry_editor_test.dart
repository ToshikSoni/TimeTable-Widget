import 'package:cadence/core/models.dart';
import 'package:cadence/core/store.dart';
import 'package:cadence/ui/app_scope.dart';
import 'package:cadence/ui/editors/entry_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AppStore> pumpEditor(WidgetTester tester, {required int rotation}) async {
    final tt = Timetable(
      name: 'Test',
      kind: TimetableKind.routine,
      rotationWeeks: rotation,
      rotationStart: DateTime(2025, 1, 6),
    );
    final store = AppStore.memory(AppData(timetables: [tt], activeTimetableId: tt.id));
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        store: store,
        child: const MaterialApp(home: EntryEditor(weekday: 1)),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'Swimming');
    return store;
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('weekly timetables do not ask about weeks', (tester) async {
    final store = await pumpEditor(tester, rotation: 1);
    expect(find.text('Week A'), findsNothing);
    await save(tester);
    expect(store.timetable!.entries.single.weeks, isNull);
  });

  testWidgets('an entry can run in week B only', (tester) async {
    final store = await pumpEditor(tester, rotation: 2);
    expect(find.text('Every week'), findsOneWidget);
    await tester.tap(find.text('Week B'));
    await tester.pump();
    await save(tester);
    final e = store.timetable!.entries.single;
    expect(e.title, 'Swimming');
    expect(e.weeks, [1]);
  });

  testWidgets('picking every week clears the selection', (tester) async {
    final store = await pumpEditor(tester, rotation: 2);
    await tester.tap(find.text('Week A'));
    await tester.pump();
    await tester.tap(find.text('Week B'));
    await tester.pump();
    await save(tester);
    expect(store.timetable!.entries.single.weeks, isNull, reason: 'A + B is every week');
  });
}
