import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/formatting.dart';
import '../../core/models.dart';
import '../../core/schedule.dart';
import '../../services/desktop.dart';
import '../app_scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/now_card.dart';

/// The compact always-available view shown when the window is in desktop
/// widget mode: what's on now, what's next and the rest of today.
class DesktopWidgetView extends StatelessWidget {
  const DesktopWidgetView({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = context.store.timetable;
    final now = ClockScope.now(context);
    final c = context.colors;
    final shell = DesktopShell.instance;

    return Scaffold(
      backgroundColor: c.surfaceContainerLow,
      body: DragToResizeArea(
        resizeEdgeSize: 6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DragToMoveArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE').format(now).toUpperCase(),
                            style: context.text.labelSmall?.copyWith(
                              color: c.primary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            '${DateFormat('d MMMM').format(now)} · ${context.timeFormat.time(now)}',
                            style: context.text.titleMedium?.copyWith(fontFeatures: tabular),
                          ),
                        ],
                      ),
                    ),
                    _IconBtn(Icons.open_in_full_rounded, 'Open Cadence', shell.exitWidgetMode),
                    _IconBtn(Icons.close_rounded, 'Hide widget', shell.hideWidget),
                  ],
                ),
              ),
            ),
            Expanded(
              child: tt == null
                  ? const Center(child: Text('No timetable'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      children: [
                        NowCard(timetable: tt, now: now, compact: true),
                        const SizedBox(height: 12),
                        ..._today(context, tt, now),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _today(BuildContext context, Timetable tt, DateTime now) {
    final plan = ScheduleEngine.dayPlan(tt, now);
    final fmt = context.timeFormat;
    if (plan.active.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            plan.isHoliday ? 'Holiday today' : 'Nothing scheduled today',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(
          plan.followsOtherDay
              ? 'TODAY · ${weekdayName(plan.effectiveWeekday!).toUpperCase()} TIMETABLE'
              : 'TODAY',
          style: context.text.labelSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
            letterSpacing: 1.1,
          ),
        ),
      ),
      for (final o in plan.active)
        Opacity(
          opacity: o.end.isBefore(now) ? 0.45 : 1,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: o.isLiveAt(now) ? context.tone(o.color).container : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 30,
                  decoration: BoxDecoration(
                    color: context.tone(o.color).accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: context.use24h ? 44 : 62,
                  child: Text(
                    fmt.time(o.start),
                    style: context.text.labelLarge?.copyWith(fontFeatures: tabular),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.shortTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall,
                      ),
                      if (o.room != null)
                        Text(
                          o.room!,
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (o.entry.kind == ClassKind.lab) const Tag('LAB', dense: true),
              ],
            ),
          ),
        ),
    ];
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn(this.icon, this.tooltip, this.onPressed);
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    iconSize: 18,
    onPressed: onPressed,
    icon: Icon(icon),
  );
}
