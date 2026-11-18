import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'format.dart';

/// The arc gauge of the connection details and the speed test: a track
/// over most of a circle, a light that grows with the speed, a needle,
/// and the number in the middle. The value glides to its new reading, so
/// a live rate reads calmly instead of twitching every tick.
class SpeedGauge extends StatelessWidget {
  const SpeedGauge({
    super.key,
    required this.mbps,
    required this.maxMbps,
    required this.label,
    this.unit = 'Mbps',
    this.trackColor,
    this.valueColor,
    this.textColor,
    this.size = const Size(250, 170),
    this.lineWidth = 11,
  });

  /// The reading, in megabits a second.
  final double mbps;

  /// The gauge's full scale (1.0 of the arc).
  final double maxMbps;

  /// The word under the number ("Download").
  final String label;
  final String unit;
  final Color? trackColor;
  final Color? valueColor;
  final Color? textColor;
  final Size size;
  final double lineWidth;

  /// A speed for the number under the gauge: one decimal under a hundred
  /// and none above; in Persian, the digits and the decimal mark follow.
  static String speedText(double mbps, {bool persian = false}) {
    final s = mbps >= 100
        ? mbps.toStringAsFixed(0)
        : mbps.toStringAsFixed(1);
    if (!persian) return s;
    return persianDigits(s).replaceAll('.', '٫');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final persian = l.localeName == 'fa';
    final track = trackColor ?? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.18);
    final value = valueColor ?? theme.colorScheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: math.min(mbps, maxMbps)),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, shown, _) => TweenAnimationBuilder<double>(
        tween: Tween(end: maxMbps),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, max, child) => Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: size,
              painter: _GaugePainter(
                fraction: max > 0 ? shown / max : 0,
                track: track,
                value: value,
                lineWidth: lineWidth,
              ),
            ),
            child,
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              speedText(shown, persian: persian),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: textColor ?? theme.colorScheme.onSurface,
                fontFeatures: const [],
              ),
            ),
            Text(
              unit,
              style: theme.textTheme.labelSmall?.copyWith(
                color: textColor ?? theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: textColor ?? theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.fraction,
    required this.track,
    required this.value,
    required this.lineWidth,
  });

  final double fraction;
  final Color track;
  final Color value;
  final double lineWidth;

  /// The arc opens at the bottom: it starts lower-left and sweeps 270°
  /// clockwise through the top.
  static const _start = 135 * math.pi / 180;
  static const _sweep = 270 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - lineWidth;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final cap = StrokeCap.round;

    // The resting track, with the tick marks inside it.
    canvas.drawArc(rect, _start, _sweep, false, Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = cap);
    final tick = Paint()
      ..color = track.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = 0; i <= 12; i++) {
      final a = _start + _sweep * i / 12;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        center + dir * (radius - lineWidth - 1.5),
        center + dir * (radius - lineWidth - 5.5),
        tick,
      );
    }

    // The reading: a sweep of light, then the needle on top of it.
    if (fraction > 0) {
      canvas.drawArc(rect, _start, _sweep * fraction, false, Paint()
        ..shader = SweepGradient(
          startAngle: _start,
          endAngle: _start + _sweep,
          colors: [value.withValues(alpha: 0.45), value],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth
        ..strokeCap = cap);
    }
    final a = _start + _sweep * fraction.clamp(0.0, 1.0);
    final tip = center + Offset(math.cos(a), math.sin(a)) * (radius - lineWidth - 8);
    canvas.drawLine(center, tip, Paint()
      ..color = value
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round);
    canvas.drawCircle(center, 3.2, Paint()..color = value);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.track != track || old.value != value;
}
