import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/formatting.dart';
import '../../core/models.dart';
import '../../core/search.dart';
import '../../services/focus_timer.dart';
import '../app_scope.dart';
import '../editors/entry_editor.dart';
import '../editors/misc_editors.dart';
import '../editors/subject_editor.dart';
import '../editors/teacher_editor.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'focus_screen.dart';

/// A quick-find palette (Ctrl+K): search classes, subjects, people and tasks,
/// or run a common action. A dialog on wide windows, a full page on phones.
Future<void> showSearchPalette(BuildContext context) {
  if (context.isMedium) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black38,
      builder: (_) => Align(
        alignment: const Alignment(0, -0.6),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 560),
            child: Material(
              type: MaterialType.card,
              clipBehavior: Clip.antiAlias,
              borderRadius: const BorderRadius.all(Radius.circular(24)),
              elevation: 8,
              child: SearchPalette(origin: context),
            ),
          ),
        ),
      ),
    );
  }
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        body: SafeArea(child: SearchPalette(origin: context)),
      ),
    ),
  );
}

class _Command {
  const _Command(this.icon, this.title, this.keywords, this.run);
  final IconData icon;
  final String title;
  final String keywords;
  final void Function(BuildContext context) run;
}

class SearchPalette extends StatefulWidget {
  const SearchPalette({super.key, required this.origin});

  /// The page that opened the palette; results open on top of it.
  final BuildContext origin;

  @override
  State<SearchPalette> createState() => _SearchPaletteState();
}

class _SearchPaletteState extends State<SearchPalette> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  int _highlight = 0;

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<_Command> _commands(Timetable? tt) {
    final noun = tt?.kind.item ?? 'class';
    final focus = FocusTimer.instance;
    return [
      _Command(
        focus.running ? Icons.pause_rounded : Icons.timer_outlined,
        focus.running ? 'Pause the focus timer' : 'Start a focus session',
        'focus pomodoro timer study start pause',
        (context) {
          focus.toggle();
          if (focus.running) openFocus(context);
        },
      ),
      if (tt != null)
        _Command(
          Icons.add_rounded,
          'New weekly $noun',
          'add new create class activity entry',
          (context) => showEditor(context, const EntryEditor()),
        ),
      _Command(
        Icons.task_alt_rounded,
        'New task or exam',
        'add new create task exam assignment homework',
        (context) => showEditor(context, const TaskEditor()),
      ),
      if (tt != null)
        _Command(
          Icons.beach_access_outlined,
          'Mark a holiday',
          'add holiday day off special vacation',
          (context) => showEditor(context, SpecialDayEditor(date: DateTime.now())),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final tt = store.timetable;
    final q = _query.text.trim();
    final words = q.toLowerCase().split(' ').where((w) => w.isNotEmpty);
    final commands = _commands(tt)
        .where(
          (c) =>
              q.isEmpty || words.every((w) => '${c.title} ${c.keywords}'.toLowerCase().contains(w)),
        )
        .toList();
    final hits = searchData(store.data, q);
    final total = commands.length + hits.length;
    if (_highlight >= total) _highlight = total == 0 ? 0 : total - 1;

    void activate(int i) {
      Navigator.of(context).pop();
      // Run against the page underneath, now that the palette is closed.
      final target = widget.origin;
      if (!target.mounted) return;
      if (i < commands.length) {
        commands[i].run(target);
      } else {
        _open(target, hits[i - commands.length]);
      }
    }

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(-1),
      },
      child: Actions(
        actions: {
          _MoveIntent: CallbackAction<_MoveIntent>(
            onInvoke: (i) => setState(() {
              if (total == 0) return;
              _highlight = (_highlight + i.delta) % total;
            }),
          ),
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() => _highlight = 0),
                onSubmitted: (_) {
                  if (total > 0) activate(_highlight);
                },
                decoration: InputDecoration(
                  hintText: tt?.kind == TimetableKind.routine
                      ? 'Search activities, people, tasks…'
                      : 'Search classes, rooms, teachers, tasks…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: total == 0
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Nothing matches “$q”.',
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: total,
                      itemBuilder: (context, i) {
                        final header = i == 0 && commands.isNotEmpty
                            ? 'Actions'
                            : i == commands.length
                            ? 'Results'
                            : null;
                        final tile = i < commands.length
                            ? _tile(
                                context,
                                icon: commands[i].icon,
                                title: commands[i].title,
                                selected: i == _highlight,
                                onTap: () => activate(i),
                              )
                            : _hitTile(
                                context,
                                tt,
                                hits[i - commands.length],
                                i == _highlight,
                                () => activate(i),
                              );
                        if (header == null) return tile;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SectionHeader(header, padding: const EdgeInsets.fromLTRB(20, 8, 20, 6)),
                            tile,
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? color,
    required bool selected,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: ListTile(
      selected: selected,
      selectedTileColor: context.colors.secondaryContainer.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: (color ?? context.colors.primary).withValues(alpha: 0.14),
        foregroundColor: color ?? context.colors.primary,
        child: Icon(icon, size: 20),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    ),
  );

  Widget _hitTile(
    BuildContext context,
    Timetable? tt,
    SearchHit h,
    bool selected,
    VoidCallback onTap,
  ) {
    final fmt = context.timeFormat;
    switch (h.kind) {
      case SearchKind.entry:
        final e = h.entry!;
        final s = tt?.subject(e.subjectId);
        final teacher = tt?.teacher(e.teacherId) ?? tt?.teacher(s?.teacherId);
        return _tile(
          context,
          icon: e.kind == ClassKind.lab ? Icons.science_outlined : Icons.schedule_rounded,
          color: context.tone(e.color ?? s?.color ?? 0xFF8A8F98).accent,
          title: s?.name ?? e.title ?? e.kind.label,
          subtitle: [
            '${weekdayName(e.weekday)} ${fmt.minutes(e.start)} – ${fmt.minutes(e.end)}',
            ?(e.room ?? s?.room),
            ?teacher?.displayName,
            if (e.group != null) 'Group ${e.group}',
            if (e.weeks != null && e.weeks!.isNotEmpty) e.weeks!.map(rotationLabel).join('/'),
          ].join(' · '),
          selected: selected,
          onTap: onTap,
        );
      case SearchKind.subject:
        final s = h.subject!;
        return _tile(
          context,
          icon: Icons.menu_book_outlined,
          color: context.tone(s.color).accent,
          title: s.name,
          subtitle: [
            if (s.code.isNotEmpty) s.code,
            ?tt?.teacher(s.teacherId)?.displayName,
            if (!s.enrolled) 'Not enrolled',
          ].join(' · '),
          selected: selected,
          onTap: onTap,
        );
      case SearchKind.teacher:
        final t = h.teacher!;
        return _tile(
          context,
          icon: Icons.person_outline_rounded,
          title: t.displayName,
          subtitle: [if (t.code.isNotEmpty) t.code, ?t.email].join(' · '),
          selected: selected,
          onTap: onTap,
        );
      case SearchKind.task:
        final t = h.task!;
        return _tile(
          context,
          icon: t.done ? Icons.check_circle_outline_rounded : Icons.assignment_outlined,
          title: t.title,
          subtitle: [
            t.type.label,
            if (t.due != null) DateFormat('EEE d MMM').format(t.due!),
            if (t.done) 'Done',
          ].join(' · '),
          selected: selected,
          onTap: onTap,
        );
    }
  }

  void _open(BuildContext context, SearchHit h) {
    switch (h.kind) {
      case SearchKind.entry:
        showEditor(context, EntryEditor(entry: h.entry));
      case SearchKind.subject:
        showEditor(context, SubjectEditor(subject: h.subject));
      case SearchKind.teacher:
        showEditor(context, TeacherEditor(teacher: h.teacher));
      case SearchKind.task:
        showEditor(context, TaskEditor(task: h.task));
    }
  }
}

class _MoveIntent extends Intent {
  const _MoveIntent(this.delta);
  final int delta;
}
