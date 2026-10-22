import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/sample_data.dart';
import '../app_scope.dart';
import '../editors/misc_editors.dart';
import '../widgets/common.dart';
import '../widgets/illustrations.dart';
import 'settings/data_actions.dart';

/// Shown when there is no timetable yet.
class NoTimetable extends StatelessWidget {
  const NoTimetable({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: EmptyState(
      illustration: const Illustration(Art.calendar),
      title: 'No timetable yet',
      message: 'Create your own, import one a classmate shared, or explore the example.',
      action: Column(
        children: [
          FilledButton.icon(
            onPressed: () => showEditor(
              context,
              TimetableDetailsEditor(
                timetable: Timetable(name: 'My timetable', periods: defaultPeriods()),
                isNew: true,
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create timetable'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => DataActions.importFile(context),
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Import a file'),
          ),
          TextButton(
            onPressed: () => context.readStore.loadSample(),
            child: const Text('Load the example timetable'),
          ),
        ],
      ),
    ),
  );
}
