import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatting.dart';
import '../../core/models.dart';
import '../../core/schedule.dart';
import '../app_scope.dart';
import '../editors/entry_editor.dart';
import '../editors/subject_editor.dart';
import '../theme.dart';
import 'common.dart';

/// A class in the day timeline.
class ClassTile extends StatelessWidget {
  const ClassTile({
    super.key,
    required this.occurrence,
    required this.now,
    this.showAttendance = true,
    this.carried = false,
  });

  final Occurrence occurrence;
  final DateTime now;

  /// Started the previous day and runs into this one (e.g. sleep).
  final bool carried;
  final bool showAttendance;

  @override
  Widget build(BuildContext context) {
    final o = occurrence;
    final tone = context.tone(o.color);
    final fmt = context.timeFormat;
    final live = o.isLiveAt(now);
    final past = !o.cancelled && !o.end.isAfter(now);
    final tt = context.store.timetable;
    final status = tt?.attendance[o.key];

    return Opacity(
      opacity: o.cancelled
          ? 0.6
          : past
          ? 0.62
          : 1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: context.use24h ? 52 : 66,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fmt.time(o.start),
                    style: context.text.labelLarge?.copyWith(
                      fontFeatures: tabular,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fmt.time(o.end),
                    style: context.text.labelSmall?.copyWith(
                      fontFeatures: tabular,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: tone.container,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: live ? tone.accent : Colors.transparent, width: 1.6),
                boxShadow: live
                    ? [
                        BoxShadow(
                          color: tone.accent.withValues(alpha: 0.22),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => showClassDetails(context, o),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 8, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 44,
                          margin: const EdgeInsets.only(left: 10, right: 12),
                          decoration: BoxDecoration(
                            color: tone.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Expanded(child: _body(context, tone, live)),
                        if (showAttendance && o.tracksAttendance && !o.start.isAfter(now))
                          _AttendanceButtons(occurrence: o, status: status, tone: tone),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, SubjectTone tone, bool live) {
    final o = occurrence;
    final meta = [
      if (o.room != null) o.room!,
      if (o.teacher != null) o.teacher!.code.isNotEmpty ? o.teacher!.code : o.teacher!.name,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (o.code.isNotEmpty)
              Text(
                o.code,
                style: context.text.labelSmall?.copyWith(
                  color: tone.muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            if (o.countsAttendance && o.entry.kind != ClassKind.lecture)
              Tag(o.entry.kind.label.toUpperCase(), color: tone.accent, dense: true),
            if (o.entry.group != null) Tag(o.entry.group!, color: tone.accent, dense: true),
            if (o.extra) Tag('EXTRA', color: context.colors.tertiary, dense: true),
            if (o.cancelled) Tag('CANCELLED', color: context.colors.error, dense: true),
            if (carried) Tag('SINCE YESTERDAY', color: tone.accent, dense: true),
            if (live) Tag('NOW', color: tone.accent, icon: Icons.circle, dense: true),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          o.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.titleMedium?.copyWith(
            color: tone.onContainer,
            decoration: o.cancelled ? TextDecoration.lineThrough : null,
          ),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.place_outlined, size: 14, color: tone.muted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  meta.join('  ·  '),
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: tone.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AttendanceButtons extends StatelessWidget {
  const _AttendanceButtons({required this.occurrence, required this.status, required this.tone});
  final Occurrence occurrence;
  final AttendanceStatus? status;
  final SubjectTone tone;

  @override
  Widget build(BuildContext context) {
    Widget button(AttendanceStatus s, IconData icon, String tip, Color color) {
      final selected = status == s;
      return Tooltip(
        message: tip,
        child: InkResponse(
          radius: 22,
          onTap: () => context.readStore.setAttendance(occurrence.key, selected ? null : s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            width: 32,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: selected ? color : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? color : tone.muted.withValues(alpha: 0.35),
                width: 1.4,
              ),
            ),
            child: Icon(icon, size: 17, color: selected ? Colors.white : tone.muted),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(AttendanceStatus.present, Icons.check_rounded, 'Attended', const Color(0xFF2F9E62)),
        button(AttendanceStatus.absent, Icons.close_rounded, 'Missed', context.colors.error),
      ],
    );
  }
}

/// A free gap or break between classes.
class GapTile extends StatelessWidget {
  const GapTile({
    super.key,
    required this.label,
    required this.duration,
    this.icon = Icons.coffee_outlined,
  });
  final String label;
  final Duration duration;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: context.use24h ? 52 : 66),
    child: Row(
      children: [
        Icon(icon, size: 16, color: context.colors.outline),
        const SizedBox(width: 8),
        Text(
          '$label · ${humanDuration(duration)}',
          style: context.text.labelMedium?.copyWith(color: context.colors.outline),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CustomPaint(
            size: const Size.fromHeight(1),
            painter: _DashPainter(context.colors.outlineVariant),
          ),
        ),
      ],
    ),
  );
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0), Offset(x + 3.5, 0), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

Future<void> showClassDetails(BuildContext context, Occurrence o) => showModalBottomSheet(
  useRootNavigator: true,
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => _ClassDetails(occurrence: o),
);

class _ClassDetails extends StatelessWidget {
  const _ClassDetails({required this.occurrence});
  final Occurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final o = occurrence;
    final store = context.store;
    final tt = store.timetable!;
    final tone = context.tone(o.color);
    final fmt = context.timeFormat;
    final status = tt.attendance[o.key];
    final dateLabel = DateFormat('EEEE, d MMMM').format(o.date);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: tone.container,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_kindIcon(o.entry.kind), color: tone.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (o.code.isNotEmpty)
                      Text(
                        o.code,
                        style: context.text.labelMedium?.copyWith(
                          color: tone.accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                    Text(o.title, style: context.text.titleLarge),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _InfoRow(
            Icons.schedule_rounded,
            '${fmt.rangeOf(o.start, o.end)} · ${humanDuration(o.end.difference(o.start))}',
            dateLabel,
          ),
          if (o.room != null) _InfoRow(Icons.place_outlined, o.room!, 'Room'),
          if (o.teacher != null)
            _InfoRow(
              Icons.person_outline_rounded,
              o.teacher!.displayName,
              o.teacher!.code.isNotEmpty && o.teacher!.code != o.teacher!.name
                  ? o.teacher!.code
                  : 'Teacher',
              trailing: o.teacher!.email == null
                  ? null
                  : IconButton(
                      tooltip: 'Email',
                      icon: const Icon(Icons.mail_outline_rounded),
                      onPressed: () => launchUrl(Uri(scheme: 'mailto', path: o.teacher!.email)),
                    ),
            ),
          if (o.countsAttendance)
            _InfoRow(
              Icons.category_outlined,
              o.entry.kind.label,
              o.entry.group == null ? 'Everyone' : 'Group ${o.entry.group}',
            ),
          if (o.entry.alarm || o.entry.doNotDisturb)
            _InfoRow(
              o.entry.alarm ? Icons.alarm_rounded : Icons.do_not_disturb_on_outlined,
              [
                if (o.entry.alarm) 'Rings an alarm',
                if (o.entry.doNotDisturb) 'Do not disturb',
              ].join(' · '),
              'Alerts',
            ),
          if (o.entry.note != null && o.entry.note!.isNotEmpty)
            _InfoRow(Icons.notes_rounded, o.entry.note!, 'Note'),
          if (o.changeReason != null)
            _InfoRow(
              Icons.info_outline_rounded,
              o.changeReason!,
              o.cancelled ? 'Cancelled' : 'Change',
            ),
          if (o.tracksAttendance && !o.start.isAfter(DateTime.now())) ...[
            const SectionHeader('Attendance'),
            SegmentedButton<AttendanceStatus?>(
              showSelectedIcon: false,
              emptySelectionAllowed: true,
              segments: const [
                ButtonSegment(
                  value: AttendanceStatus.present,
                  icon: Icon(Icons.check_rounded),
                  label: Text('Attended'),
                ),
                ButtonSegment(
                  value: AttendanceStatus.absent,
                  icon: Icon(Icons.close_rounded),
                  label: Text('Missed'),
                ),
              ],
              selected: {?status},
              onSelectionChanged: (s) => store.setAttendance(o.key, s.isEmpty ? null : s.first),
            ),
          ],
          const SectionHeader('Actions'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!o.extra)
                ActionChip(
                  avatar: Icon(
                    o.cancelled ? Icons.restore_rounded : Icons.event_busy_outlined,
                    size: 18,
                  ),
                  label: Text(
                    o.cancelled ? 'Restore' : 'Cancel on ${DateFormat('d MMM').format(o.date)}',
                  ),
                  onPressed: () {
                    store.toggleCancelled(o.date, o.entry.id);
                    Navigator.pop(context);
                  },
                ),
              if (o.extra)
                ActionChip(
                  avatar: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remove'),
                  onPressed: () {
                    final change = tt.changes.where((c) => c.extra?.id == o.entry.id);
                    if (change.isNotEmpty) store.removeChange(change.first.id);
                    Navigator.pop(context);
                  },
                ),
              if (!o.extra)
                ActionChip(
                  avatar: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit every week'),
                  onPressed: () {
                    Navigator.pop(context);
                    showEditor(context, EntryEditor(entry: o.entry));
                  },
                ),
              if (o.subject != null)
                ActionChip(
                  avatar: const Icon(Icons.palette_outlined, size: 18),
                  label: const Text('Subject settings'),
                  onPressed: () {
                    Navigator.pop(context);
                    showEditor(context, SubjectEditor(subject: o.subject));
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

IconData _kindIcon(ClassKind k) => switch (k) {
  ClassKind.lecture => Icons.school_outlined,
  ClassKind.lab => Icons.science_outlined,
  ClassKind.tutorial => Icons.forum_outlined,
  ClassKind.activity => Icons.sports_soccer_outlined,
  ClassKind.exam => Icons.edit_note_rounded,
  ClassKind.other => Icons.event_outlined,
};

IconData kindIcon(ClassKind k) => _kindIcon(k);

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.title, this.subtitle, {this.trailing});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, size: 22, color: context.colors.onSurfaceVariant),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              Text(
                subtitle,
                style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}
