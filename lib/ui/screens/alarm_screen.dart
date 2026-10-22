import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/reminders.dart';
import '../../core/schedule.dart';
import '../../services/notifications.dart';
import '../app_scope.dart';
import '../theme.dart';

/// Full-screen wake-up alarm with snooze and dismiss.
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key, required this.reminder});
  final PlannedReminder reminder;

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ClockScope.now(context);
    final tt = context.store.timetable;
    final first = tt == null ? null : ScheduleEngine.next(tt, now, days: 1);
    final fmt = context.timeFormat;
    final c = context.colors;
    final body = widget.reminder.body.isNotEmpty
        ? widget.reminder.body
        : first == null
        ? 'Have a great day'
        : 'First class: ${first.title} at ${fmt.time(first.start)}${first.room != null ? ' in ${first.room}' : ''}';

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.primary, Color.lerp(c.primary, c.tertiary, 0.6)!],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Spacer(),
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, child) =>
                          CustomPaint(painter: _Ripple(_pulse.value, c.onPrimary), child: child),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: c.onPrimary.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.alarm_rounded, size: 56, color: c.onPrimary),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      fmt.time(now),
                      style: context.text.displayLarge?.copyWith(
                        color: c.onPrimary,
                        fontWeight: FontWeight.w800,
                        fontFeatures: tabular,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, d MMMM').format(now),
                      style: context.text.titleMedium?.copyWith(
                        color: c.onPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      widget.reminder.title,
                      textAlign: TextAlign.center,
                      style: context.text.headlineSmall?.copyWith(color: c.onPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: context.text.bodyLarge?.copyWith(
                        color: c.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: c.onPrimary,
                          foregroundColor: c.primary,
                          minimumSize: const Size.fromHeight(56),
                        ),
                        onPressed: NotificationService.instance.dismissAlarm,
                        child: const Text('I’m up'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.onPrimary,
                          side: BorderSide(color: c.onPrimary.withValues(alpha: 0.5)),
                          minimumSize: const Size.fromHeight(56),
                        ),
                        onPressed: () async {
                          await NotificationService.instance.snooze();
                          if (context.mounted) context.toast('Snoozed for $snoozeMinutes minutes');
                        },
                        child: const Text('Snooze $snoozeMinutes min'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Ripple extends CustomPainter {
  _Ripple(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      canvas.drawCircle(
        center,
        60 + p * 70,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: (1 - p) * 0.35),
      );
    }
    canvas.drawCircle(
      center,
      60 + math.sin(t * math.pi * 2) * 2,
      Paint()..color = Colors.transparent,
    );
  }

  @override
  bool shouldRepaint(_Ripple old) => old.t != t;
}
