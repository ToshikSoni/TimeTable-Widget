import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/models.dart';
import '../../core/schedule.dart';
import '../app_scope.dart';
import '../theme.dart';
import 'class_tile.dart';
import 'common.dart';

/// The hero card on the Today screen: what's on now and what's next.
class NowCard extends StatelessWidget {
  const NowCard({super.key, required this.timetable, required this.now, this.compact = false});

  final Timetable timetable;
  final DateTime now;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final live = ScheduleEngine.current(timetable, now);
    final next = ScheduleEngine.next(timetable, now);
    final Widget child;
    if (live != null) {
      final after = next != null && dateOnly(next.start) == dateOnly(now) ? next : null;
      child = _LiveCard(
        key: ValueKey('live${live.key}'),
        o: live,
        next: after,
        now: now,
        compact: compact,
      );
    } else if (next != null) {
      child = _NextCard(key: ValueKey('next${next.key}'), o: next, now: now, compact: compact);
    } else {
      child = _IdleCard(key: const ValueKey('idle'), compact: compact);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(a), child: child),
      ),
      child: child,
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.color, required this.child, this.onTap});
  final Color color;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = context.tone(color.toARGB32());
    final dark = context.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(tone.accent, Colors.black, dark ? 0.35 : 0.0)!,
            Color.lerp(tone.accent, dark ? Colors.black : Colors.white, dark ? 0.6 : 0.25)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: tone.accent.withValues(alpha: dark ? 0.18 : 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      ),
    );
  }
}

const _onCard = Colors.white;
final _onCardMuted = Colors.white.withValues(alpha: 0.78);

class _LiveCard extends StatelessWidget {
  const _LiveCard({
    super.key,
    required this.o,
    required this.next,
    required this.now,
    required this.compact,
  });
  final Occurrence o;
  final Occurrence? next;
  final DateTime now;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fmt = context.timeFormat;
    final left = o.end.difference(now);
    final meta = [
      if (o.room != null) o.room!,
      if (o.teacher != null) o.teacher!.displayName,
    ].join(' · ');
    return _Shell(
      color: Color(o.color),
      onTap: () => showClassDetails(context, o),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProgressRing(
                value: o.progressAt(now),
                color: _onCard,
                track: Colors.white24,
                size: compact ? 58 : 72,
                stroke: compact ? 5 : 7,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${left.inMinutes + 1}',
                      style: TextStyle(
                        color: _onCard,
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 17 : 21,
                        height: 1,
                        fontFeatures: tabular,
                      ),
                    ),
                    Text(
                      'min',
                      style: TextStyle(
                        color: _onCardMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Pulse(label: 'HAPPENING NOW'),
                    const SizedBox(height: 6),
                    Text(
                      o.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: (compact ? context.text.titleMedium : context.text.titleLarge)
                          ?.copyWith(color: _onCard),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium?.copyWith(color: _onCardMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (!compact || next != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    next == null ? Icons.flag_outlined : Icons.arrow_forward_rounded,
                    color: _onCard,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      next == null
                          ? 'Last class today · ends ${fmt.time(o.end)}'
                          : 'Next: ${next!.shortTitle} at ${fmt.time(next!.start)}${next!.room != null ? ' · ${next!.room}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelLarge?.copyWith(color: _onCard),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NextCard extends StatelessWidget {
  const _NextCard({super.key, required this.o, required this.now, required this.compact});
  final Occurrence o;
  final DateTime now;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fmt = context.timeFormat;
    final until = o.start.difference(now);
    final sameDay = dateOnly(o.start) == dateOnly(now);
    final when = sameDay
        ? 'UP NEXT · IN ${humanDuration(until).toUpperCase()}'
        : 'NEXT CLASS · ${relativeDay(o.start, now).toUpperCase()}';
    final meta = [fmt.rangeOf(o.start, o.end), if (o.room != null) o.room!].join(' · ');
    return _Shell(
      color: Color(o.color),
      onTap: () => showClassDetails(context, o),
      child: Row(
        children: [
          Container(
            width: compact ? 58 : 72,
            height: compact ? 58 : 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  sameDay ? humanDuration(until, short: true) : weekdayShort(o.start.weekday),
                  style: TextStyle(
                    color: _onCard,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 15 : 18,
                    fontFeatures: tabular,
                  ),
                ),
                Text(
                  sameDay ? 'to go' : fmt.time(o.start),
                  style: TextStyle(color: _onCardMuted, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  when,
                  style: context.text.labelSmall?.copyWith(color: _onCardMuted, letterSpacing: 1),
                ),
                const SizedBox(height: 6),
                Text(
                  o.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: (compact ? context.text.titleMedium : context.text.titleLarge)?.copyWith(
                    color: _onCard,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(color: _onCardMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdleCard extends StatelessWidget {
  const _IdleCard({super.key, required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) => _Shell(
    color: context.colors.primary,
    child: Row(
      children: [
        const Icon(Icons.wb_twilight_rounded, color: _onCard, size: 36),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nothing scheduled', style: context.text.titleLarge?.copyWith(color: _onCard)),
              Text(
                'No classes in the next two weeks.',
                style: context.text.bodyMedium?.copyWith(color: _onCardMuted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// A label with a softly pulsing live dot.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.label});
  final String label;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context)) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 14,
        height: 14,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 6 + 8 * _c.value,
                height: 6 + 8 * _c.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.5 * (1 - _c.value)),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        widget.label,
        style: context.text.labelSmall?.copyWith(color: _onCardMuted, letterSpacing: 1),
      ),
    ],
  );
}
