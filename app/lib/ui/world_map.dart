import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import 'world_map_data.dart';

/// The dotted world map with the connection's story on it: the user's pin
/// at home (Tehran), the exit pin on the server's country, and a dashed
/// light running between them while the VPN is connected. The map keeps
/// its own left-to-right geography inside the right-to-left page.
class WorldMap extends StatefulWidget {
  const WorldMap({
    super.key,
    required this.dotColor,
    required this.homeColor,
    required this.exitColor,
    this.exitCode = '',
    this.connected = false,
    this.dotRadius = 1.1,
  });

  final Color dotColor;
  final Color homeColor;
  final Color exitColor;

  /// The exit's country code, or '' for no exit pin at all.
  final String exitCode;

  /// Whether the arc to the exit is drawn.
  final bool connected;

  final double dotRadius;

  @override
  State<WorldMap> createState() => _WorldMapState();
}

class _WorldMapState extends State<WorldMap> with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    // The dashes only travel while the connection is on the map.
    if (widget.connected) _flow.repeat();
  }

  @override
  void didUpdateWidget(WorldMap old) {
    super.didUpdateWidget(old);
    if (widget.connected && !_flow.isAnimating) {
      _flow.repeat();
    } else if (!widget.connected && _flow.isAnimating) {
      _flow.stop();
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: AnimatedBuilder(
        animation: _flow,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _WorldMapPainter(widget, _flow.value),
        ),
      ),
    );
  }
}

class _WorldMapPainter extends CustomPainter {
  const _WorldMapPainter(this.w, this.t);

  final WorldMap w;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / kWorldWidth, size.height / kWorldHeight);
    final off = Offset(
      (size.width - kWorldWidth * scale) / 2,
      (size.height - kWorldHeight * scale) / 2,
    );
    Offset at(double x, double y) => Offset(off.dx + x * scale, off.dy + y * scale);
    List<double>? pin(String code) => kCountryPins[code.toUpperCase()];

    // The land: one round point per cell.
    final dots = <Offset>[
      for (var i = 0; i + 1 < kWorldDots.length; i += 2)
        at(kWorldDots[i], kWorldDots[i + 1]),
    ];
    canvas.drawPoints(
      PointMode.points,
      dots,
      Paint()
        ..color = w.dotColor
        ..strokeWidth = w.dotRadius * 2 * math.max(scale, 0.75)
        ..strokeCap = StrokeCap.round,
    );

    // The exit pin, the home pin, and the arc between them.
    final exit = pin(w.exitCode);
    final home = projectGeo(kHomePinGeo[0], kHomePinGeo[1]);
    if (w.connected && exit != null) {
      final from = at(home.x, home.y);
      final to = at(projectGeo(exit[0], exit[1]).x, projectGeo(exit[0], exit[1]).y);
      final dist = (to - from).distance;
      final mid = Offset((from.dx + to.dx) / 2, math.min(from.dy, to.dy) - dist * 0.3);
      final arc = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy);

      // Dashes travel from home to the server.
      final metric = arc.computeMetrics().first;
      final unit = math.max(scale * 3.2, 3.0);
      final dash = unit, gap = unit * 1.15;
      final shift = (t * (dash + gap)) % (dash + gap);
      final dashed = Path();
      for (double s = -shift; s < metric.length; s += dash + gap) {
        dashed.addPath(
          metric.extractPath(
            math.max(0, s),
            math.min(metric.length, s + dash),
          ),
          Offset.zero,
        );
      }
      canvas.drawPath(
        dashed,
        Paint()
          ..color = w.exitColor.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.9
          ..strokeCap = StrokeCap.round,
      );

      // A ring breathing out of the server pin.
      final breathe = (math.sin(t * math.pi * 2) + 1) / 2;
      canvas.drawCircle(
        to,
        5 + breathe * 9,
        Paint()..color = w.exitColor.withValues(alpha: 0.38 * (1 - breathe)),
      );
      canvas.drawCircle(
        to,
        3.4,
        Paint()
          ..color = w.exitColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      canvas.drawCircle(to, 2.1, Paint()..color = w.exitColor);
    } else if (exit != null && !w.connected) {
      // The chosen server waits, quietly, while the VPN is off.
      final to = at(projectGeo(exit[0], exit[1]).x, projectGeo(exit[0], exit[1]).y);
      canvas.drawCircle(
        to,
        2.4,
        Paint()
          ..color = w.exitColor.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    canvas.drawCircle(
      at(home.x, home.y),
      2.6,
      Paint()
        ..color = w.homeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    canvas.drawCircle(at(home.x, home.y), 1.5, Paint()..color = w.homeColor);
  }

  @override
  bool shouldRepaint(_WorldMapPainter old) =>
      old.t != t || old.w != w;
}
