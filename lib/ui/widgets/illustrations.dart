import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/palette.dart';

enum Art { calendar, freeDay, tasks, bell, chart, widget }

/// Small geometric illustrations drawn in the current colour scheme, with a
/// slow floating motion so empty screens don't feel dead.
class Illustration extends StatefulWidget {
  const Illustration(this.art, {super.key, this.animate = true});
  final Art art;
  final bool animate;

  @override
  State<Illustration> createState() => _IllustrationState();
}

class _IllustrationState extends State<Illustration> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animate && !MediaQuery.disableAnimationsOf(context)) {
      _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1.3,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(painter: _ArtPainter(widget.art, scheme, _c.value)),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.art, this.s, this.t);
  final Art art;
  final ColorScheme s;
  final double t;

  double get bob => math.sin(t * math.pi * 2) * 4;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Soft backdrop blob.
    final blob = Paint()..color = s.primaryContainer.withValues(alpha: 0.45);
    canvas.drawCircle(Offset(w * 0.5, h * 0.55), h * 0.46, blob);
    canvas.drawCircle(Offset(w * 0.82, h * 0.2), h * 0.07, Paint()..color = s.tertiaryContainer);
    canvas.drawCircle(Offset(w * 0.15, h * 0.78), h * 0.045, Paint()..color = s.secondaryContainer);

    switch (art) {
      case Art.calendar:
        _calendar(canvas, size);
      case Art.freeDay:
        _freeDay(canvas, size);
      case Art.tasks:
        _tasks(canvas, size);
      case Art.bell:
        _bell(canvas, size);
      case Art.chart:
        _chart(canvas, size);
      case Art.widget:
        _widget(canvas, size);
    }
  }

  Paint fill(Color c) => Paint()..color = c;

  RRect card(Rect r, [double radius = 14]) => RRect.fromRectAndRadius(r, Radius.circular(radius));

  void _shadowed(Canvas canvas, RRect r, Color color) {
    canvas.drawRRect(
      r.shift(const Offset(0, 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawRRect(r, fill(color));
  }

  void _calendar(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = Rect.fromCenter(center: Offset(w * 0.47, h * 0.53), width: w * 0.56, height: h * 0.6);
    _shadowed(canvas, card(r, 16), s.surfaceContainerLowest);
    final header = Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.2);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        header,
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
      ),
      fill(s.primary),
    );
    for (final x in [0.28, 0.72]) {
      canvas.drawRRect(
        card(Rect.fromCenter(center: Offset(r.left + r.width * x, r.top), width: 8, height: 18), 4),
        fill(s.onSurface.withValues(alpha: 0.6)),
      );
    }
    // Colour blocks laid out like a week.
    const cols = 4, rows = 3;
    final gx = r.width * 0.06, top = header.bottom + gx;
    final cw = (r.width - gx * (cols + 1)) / cols;
    final ch = (r.bottom - top - gx * (rows)) / rows;
    var i = 0;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        if ((row + col) % 3 == 2) continue;
        final rect = Rect.fromLTWH(r.left + gx + col * (cw + gx), top + row * (ch + gx), cw, ch);
        canvas.drawRRect(
          card(rect, 5),
          fill(Color(kSubjectPalette[i++ % 6]).withValues(alpha: 0.85)),
        );
      }
    }
    // Clock badge.
    final c = Offset(r.right - 4, r.bottom - 6 + bob);
    final rad = h * 0.13;
    canvas.drawCircle(
      c + const Offset(0, 4),
      rad,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(c, rad, fill(s.tertiary));
    canvas.drawCircle(c, rad * 0.78, fill(s.onTertiary));
    final hand = Paint()
      ..color = s.tertiary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final a = t * math.pi * 2;
    canvas.drawLine(
      c,
      c + Offset(math.cos(a - math.pi / 2), math.sin(a - math.pi / 2)) * rad * 0.6,
      hand,
    );
    canvas.drawLine(c, c + Offset(rad * 0.4, 0), hand);
  }

  void _freeDay(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final sun = Offset(w * 0.62, h * 0.38 + bob);
    for (var i = 0; i < 10; i++) {
      final a = i / 10 * math.pi * 2 + t * math.pi / 3;
      canvas.drawLine(
        sun + Offset(math.cos(a), math.sin(a)) * h * 0.15,
        sun + Offset(math.cos(a), math.sin(a)) * h * 0.2,
        Paint()
          ..color = s.tertiary.withValues(alpha: 0.7)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(sun, h * 0.11, fill(s.tertiary));
    final hill1 = Path()
      ..moveTo(w * 0.1, h * 0.85)
      ..quadraticBezierTo(w * 0.35, h * 0.45, w * 0.62, h * 0.85)
      ..close();
    final hill2 = Path()
      ..moveTo(w * 0.38, h * 0.85)
      ..quadraticBezierTo(w * 0.66, h * 0.52, w * 0.92, h * 0.85)
      ..close();
    canvas.drawPath(hill1, fill(s.primary));
    canvas.drawPath(hill2, fill(s.secondary));
    canvas.drawRRect(
      card(Rect.fromLTWH(w * 0.08, h * 0.84, w * 0.86, h * 0.04), 4),
      fill(s.primary.withValues(alpha: 0.6)),
    );
  }

  void _tasks(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = Rect.fromCenter(center: Offset(w * 0.5, h * 0.54), width: w * 0.46, height: h * 0.66);
    _shadowed(canvas, card(r, 14), s.surfaceContainerLowest);
    canvas.drawRRect(
      card(
        Rect.fromCenter(center: Offset(r.center.dx, r.top + 2), width: r.width * 0.4, height: 14),
        6,
      ),
      fill(s.primary),
    );
    for (var i = 0; i < 3; i++) {
      final y = r.top + r.height * (0.25 + i * 0.24);
      final box = Rect.fromLTWH(r.left + r.width * 0.12, y, 18, 18);
      final done = i < 2;
      canvas.drawRRect(card(box, 5), fill(done ? s.primary : s.surfaceContainerHighest));
      if (done) {
        final p = Path()
          ..moveTo(box.left + 4, box.center.dy)
          ..lineTo(box.left + 8, box.bottom - 5)
          ..lineTo(box.right - 4, box.top + 5);
        canvas.drawPath(
          p,
          Paint()
            ..color = s.onPrimary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawRRect(
        card(Rect.fromLTWH(box.right + 10, y + 5, r.width * (i == 1 ? 0.38 : 0.5), 8), 4),
        fill(s.onSurface.withValues(alpha: done ? 0.18 : 0.35)),
      );
    }
    final pencil = Offset(r.right + 6, r.bottom - 30 + bob);
    canvas.save();
    canvas.translate(pencil.dx, pencil.dy);
    canvas.rotate(-0.7);
    canvas.drawRRect(card(const Rect.fromLTWH(-8, -40, 16, 60), 4), fill(s.tertiary));
    final tip = Path()
      ..moveTo(-8, 20)
      ..lineTo(8, 20)
      ..lineTo(0, 32)
      ..close();
    canvas.drawPath(tip, fill(s.onSurface.withValues(alpha: 0.7)));
    canvas.restore();
  }

  void _bell(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w * 0.5, h * 0.5);
    canvas.save();
    canvas.translate(c.dx, c.dy - h * 0.2);
    canvas.rotate(math.sin(t * math.pi * 6) * 0.12 * (t < 0.33 ? 1 : 0));
    final bw = h * 0.36;
    final path = Path()
      ..moveTo(-bw * 0.5, h * 0.36)
      ..quadraticBezierTo(-bw * 0.45, h * 0.08, -bw * 0.38, h * 0.06)
      ..quadraticBezierTo(0, -h * 0.08, bw * 0.38, h * 0.06)
      ..quadraticBezierTo(bw * 0.45, h * 0.08, bw * 0.5, h * 0.36)
      ..close();
    canvas.drawPath(path, fill(s.primary));
    canvas.drawRRect(
      card(Rect.fromCenter(center: Offset(0, h * 0.37), width: bw * 1.25, height: 10), 5),
      fill(s.primary),
    );
    canvas.drawCircle(Offset(0, h * 0.44), 9, fill(s.tertiary));
    canvas.drawCircle(Offset(0, -h * 0.02), 6, fill(s.primary));
    canvas.restore();
    final wave = Paint()
      ..color = s.tertiary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      final rr = h * (0.3 + i * 0.08);
      canvas.drawArc(Rect.fromCircle(center: c, radius: rr), -0.5, 0.6, false, wave);
      canvas.drawArc(Rect.fromCircle(center: c, radius: rr), math.pi - 0.1, 0.6, false, wave);
    }
  }

  void _chart(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = Rect.fromCenter(center: Offset(w * 0.5, h * 0.55), width: w * 0.55, height: h * 0.55);
    _shadowed(canvas, card(r, 16), s.surfaceContainerLowest);
    final heights = [0.5, 0.75, 0.6, 0.9];
    final bw = r.width / 9;
    for (var i = 0; i < heights.length; i++) {
      final bh = r.height * 0.7 * heights[i] * (0.9 + 0.1 * math.sin(t * math.pi * 2 + i));
      final rect = Rect.fromLTWH(
        r.left + bw * (1 + i * 2),
        r.bottom - bh - r.height * 0.12,
        bw,
        bh,
      );
      canvas.drawRRect(card(rect, 4), fill(i == 3 ? s.primary : s.primary.withValues(alpha: 0.35)));
    }
    final c = Offset(r.right, r.top + bob);
    canvas.drawCircle(c, h * 0.12, fill(s.tertiary));
    final check = Path()
      ..moveTo(c.dx - 12, c.dy)
      ..lineTo(c.dx - 3, c.dy + 9)
      ..lineTo(c.dx + 13, c.dy - 9);
    canvas.drawPath(
      check,
      Paint()
        ..color = s.onTertiary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _widget(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final screen = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.52),
      width: w * 0.62,
      height: h * 0.62,
    );
    _shadowed(canvas, card(screen, 12), s.surfaceContainerHighest);
    final widgetRect = Rect.fromLTWH(
      screen.right - screen.width * 0.48,
      screen.top + 12 + bob,
      screen.width * 0.42,
      screen.height * 0.62,
    );
    _shadowed(canvas, card(widgetRect, 12), s.surfaceContainerLowest);
    canvas.drawRRect(
      card(Rect.fromLTWH(widgetRect.left + 8, widgetRect.top + 10, widgetRect.width * 0.35, 6), 3),
      fill(s.primary),
    );
    for (var i = 0; i < 3; i++) {
      final y = widgetRect.top + 26 + i * 16.0;
      canvas.drawRRect(
        card(Rect.fromLTWH(widgetRect.left + 8, y, 4, 11), 2),
        fill(Color(kSubjectPalette[i])),
      );
      canvas.drawRRect(
        card(Rect.fromLTWH(widgetRect.left + 16, y + 2, widgetRect.width * (0.7 - i * 0.12), 6), 3),
        fill(s.onSurface.withValues(alpha: 0.25)),
      );
    }
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.t != t || old.s != s || old.art != art;
}
