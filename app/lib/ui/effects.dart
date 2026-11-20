import 'dart:math' as math;
import 'dart:ui' as ui show ImageFilter, Gradient, lerpDouble;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import 'motion.dart';

/// The app's effects, one module so every page asks for them by name:
/// the cards' frosted glass ([GlassCard]), the buttons' soft depth
/// ([SoftDepth]), the energy field behind the connection card
/// ([EnergyWaveField]), and the data flow's luminous particles
/// ([DataFlowField]). The repeating ones all ask [repeatingEffectsOn]
/// first, so a still screen still costs no frames, and the system's
/// request for less motion is honoured everywhere. The colors always
/// arrive as arguments — the effects know no palette of their own, so
/// they wear whatever the page's theme hands them.

/// How alive a flow should read, 0 to 1, from the real rate in bytes a
/// second: a quiet tunnel still breathes a little, a busy one runs at
/// full light. A smooth curve of the megabits, so a jump from 40 to 80
/// Mbps does not jump the animation with it.
double flowStrength(int bytesPerSecond) {
  final mbps = bytesPerSecond * 8 / 1e6;
  if (mbps <= 0) return 0;
  return (math.log(1 + mbps) / math.log(40)).clamp(0.0, 1.0);
}

/// The cards' frosted glass: the surface let through just enough that the
/// page's lights tint it, a rim that catches the light at the top and
/// fades toward the foot, and — where the page really moves behind the
/// card — a blur of that movement ([blur]). Without the blur the glass
/// still reads, at no cost: the lists keep scrolling smoothly on old
/// phones.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 26,
    this.onTap,
    this.blur = false,
    this.color,
    this.shadow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// Blurs what the page paints behind the card. Only where something
  /// really moves behind it — a card sitting on a plain list gains
  /// nothing but cost from it.
  final bool blur;
  final Color? color;
  final List<BoxShadow>? shadow;

  /// How much of the surface shows through: high enough that the words
  /// on the card keep their contrast, low enough that the lights behind
  /// it arrive and the pane reads as glass, not as paint.
  static double fillAlpha(bool dark) => dark ? 0.78 : 0.72;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final base = color ?? theme.colorScheme.surfaceContainer;
    final fill = base.withValues(alpha: fillAlpha(dark));
    // The rim: white where the light lands, fading toward the foot. On a
    // light page the foot takes the deep ink's faint line instead, so the
    // edge keeps showing there too.
    final rim = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        // The light lands on the pane's top edge: the rim catches it, and
        // a second, fainter band rides a little lower, the way real
        // frosted glass scatters the light along its thickness.
        Colors.white.withValues(alpha: dark ? 0.24 : 0.92),
        dark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.30),
        dark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFF0B3B78).withValues(alpha: 0.10),
      ],
      stops: const [0.0, 0.28, 1.0],
    );

    Widget glass = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: rim,
      ),
      child: Container(
        // One pixel in from the rim: the rim reads as the pane's edge.
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(math.max(0, radius - 1)),
          color: fill,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
    if (blur) {
      glass = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: glass,
        ),
      );
    }
    // The shadow rides outside the blur's clip, where it can spread over
    // the page beneath — the floating navigation's way.
    if (shadow != null) {
      glass = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: shadow,
        ),
        child: glass,
      );
    }
    if (onTap == null) return glass;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: glass,
      ),
    );
  }
}

/// The buttons' soft depth: the light rests on the top edge, the body
/// swells a little out of the page, and a soft pool of shade gathers
/// under it. The face's color may change (a protocol picked, a server
/// connected) and the depth follows it smoothly, without a jump.
class SoftDepth extends StatefulWidget {
  const SoftDepth({
    super.key,
    required this.child,
    required this.color,
    this.radius = 999,
    this.padding,
    this.duration = Motion.normal,
  });

  final Widget child;
  final Color color;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Duration duration;

  @override
  State<SoftDepth> createState() => _SoftDepthState();
}

class _SoftDepthState extends State<SoftDepth>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  late Color _from = widget.color;
  late ColorTween _tween = ColorTween(begin: _from, end: _from);

  @override
  void didUpdateWidget(SoftDepth old) {
    super.didUpdateWidget(old);
    if (widget.color != old.color) {
      _from = _tween.evaluate(_c)!;
      _tween = ColorTween(begin: _from, end: widget.color);
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = _tween.evaluate(_c)!;
    final shade = dark ? Colors.black : const Color(0xFF0B3B78);
    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        // The bulge: the light on the face's top, the shade at its foot,
        // so the face reads rounded out of the page.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(base, Colors.white, dark ? 0.07 : 0.30)!,
            base,
            Color.lerp(base, Colors.black, dark ? 0.16 : 0.05)!,
          ],
        ),
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.10 : 0.60),
        ),
        boxShadow: [
          // The pool of shade under the control.
          BoxShadow(
            color: shade.withValues(alpha: dark ? 0.40 : 0.16),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          // The environment's faint light arriving from above.
          if (dark)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
        ],
      ),
      child: widget.child,
    );
  }
}

/// The energy field behind the connection card: two calm bands of the
/// state's light run through the card like a tide under glass, and a thin
/// crest of light rides the first one. Painted while the tunnel is up (or
/// working) and the effects may run; the card rests without them.
class EnergyWaveField extends StatefulWidget {
  const EnergyWaveField({
    super.key,
    required this.color,
    required this.enabled,
    this.alpha = 0.09,
  });

  final Color color;

  /// The tunnel is up, or the switch is working for it.
  final bool enabled;
  final double alpha;

  @override
  State<EnergyWaveField> createState() => _EnergyWaveFieldState();
}

class _EnergyWaveFieldState extends State<EnergyWaveField>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _phase = ValueNotifier<double>(0);
  Ticker? _ticker;
  Duration _last = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(EnergyWaveField old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled) _sync();
  }

  void _sync() {
    final on = widget.enabled && repeatingEffectsOn(context);
    if (on && _ticker == null) {
      _last = Duration.zero;
      _ticker = createTicker(_tick)..start();
    } else if (!on && _ticker != null) {
      _ticker!.stop();
      _ticker!.dispose();
      _ticker = null;
    }
  }

  /// A wavelength drifts past in nine seconds: slow enough to read as
  /// weather, not as motion.
  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.0
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _phase.value = _phase.value + dt;
  }

  @override
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ticker == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _EnergyWavePainter(
          phase: _phase,
          color: widget.color,
          alpha: widget.alpha,
        ),
      ),
    );
  }
}

class _EnergyWavePainter extends CustomPainter {
  _EnergyWavePainter({
    required ValueListenable<double> phase,
    required this.color,
    required this.alpha,
  }) : _phase = phase,
       super(repaint: phase);

  final ValueListenable<double> _phase;
  final Color color;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = _phase.value / 9;
    for (var i = 0; i < 2; i++) {
      final share = i == 0 ? 1.0 : 0.60;
      final baseY = size.height * (0.60 + 0.13 * i);
      final amp = size.height * 0.045 * share + 2;
      // The ridge: two sines out of step, so the line reads fluid, not
      // drawn by a ruler.
      final ridge = Path();
      var first = true;
      for (var x = 0.0; x <= size.width + 3; x += 3) {
        final t = x / math.max(size.width, 1);
        final y =
            baseY +
            amp *
                math.sin(
                  (t * 1.6 + phase * (i == 0 ? 1 : -0.8) + i * 0.35) *
                      2 *
                      math.pi,
                ) +
            amp *
                0.45 *
                math.sin((t * 3.1 - phase * 1.7 + i * 0.8) * 2 * math.pi);
        if (first) {
          ridge.moveTo(x, y);
          first = false;
        } else {
          ridge.lineTo(x, y);
        }
      }
      final field = Path.from(ridge)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        field,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, baseY - amp * 2),
            Offset(0, size.height),
            [
              color.withValues(alpha: alpha * share),
              color.withValues(alpha: 0),
            ],
          ),
      );
      if (i == 0) {
        canvas.drawPath(
          ridge,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = color.withValues(alpha: alpha * 1.6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_EnergyWavePainter old) =>
      old.color != color || old.alpha != alpha;
}

/// The data flow: two curved wires through the connect pill — the tunnel
/// itself — and luminous particles running along them, the information's
/// back-and-forth made visible. Download in blue, upload in green; how
/// fast and how bright the particles run follows the real rates the core
/// reports, so a quiet tunnel breathes and a busy one streams. The
/// direction is the layout's, mirrored for right-to-left languages, the
/// way the slide pill's own travel is not: this one shows which way the
/// data goes, not which way the hand moves.
class DataFlowField extends StatefulWidget {
  const DataFlowField({
    super.key,
    required this.downRate,
    required this.upRate,
    required this.enabled,
    required this.downColor,
    required this.upColor,
    this.rtl = false,
  });

  /// The core's real rates, in bytes a second.
  final int downRate;
  final int upRate;

  /// The tunnel is up and the switch is not working for it.
  final bool enabled;
  final Color downColor;
  final Color upColor;
  final bool rtl;

  @override
  State<DataFlowField> createState() => _DataFlowFieldState();
}

class _DataFlowFieldState extends State<DataFlowField>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _phase = ValueNotifier<double>(0);
  final ValueNotifier<double> _down = ValueNotifier<double>(0);
  final ValueNotifier<double> _up = ValueNotifier<double>(0);
  Ticker? _ticker;
  Duration _last = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(DataFlowField old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled) _sync();
  }

  void _sync() {
    final on = widget.enabled && repeatingEffectsOn(context);
    if (on && _ticker == null) {
      _last = Duration.zero;
      _down.value = flowStrength(widget.downRate);
      _up.value = flowStrength(widget.upRate);
      _ticker = createTicker(_tick)..start();
    } else if (!on && _ticker != null) {
      _ticker!.stop();
      _ticker!.dispose();
      _ticker = null;
    }
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.0
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    // The readings glide toward their targets, so a burst does not jump
    // the animation; the phase runs unbounded, so a wrap never snaps the
    // particles back.
    final t = math.min(1.0, dt * 6);
    _down.value = ui.lerpDouble(_down.value, flowStrength(widget.downRate), t)!;
    _up.value = ui.lerpDouble(_up.value, flowStrength(widget.upRate), t)!;
    _phase.value = _phase.value + dt;
  }

  @override
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _phase.dispose();
    _down.dispose();
    _up.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ticker == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _DataFlowPainter(
          phase: _phase,
          down: _down,
          up: _up,
          downColor: widget.downColor,
          upColor: widget.upColor,
          rtl: widget.rtl,
        ),
      ),
    );
  }
}

class _DataFlowPainter extends CustomPainter {
  _DataFlowPainter({
    required ValueListenable<double> phase,
    required this.down,
    required this.up,
    required this.downColor,
    required this.upColor,
    required this.rtl,
  }) : _phase = phase,
       super(repaint: phase);

  final ValueListenable<double> _phase;
  final ValueListenable<double> down;
  final ValueListenable<double> up;
  final Color downColor;
  final Color upColor;
  final bool rtl;

  /// A hanging cable: in at one edge, a soft dip, out at the other.
  Path _wirePath(Size size, double at, double sag) {
    final y = size.height * at;
    final c = size.height * sag;
    return Path()
      ..moveTo(-8, y)
      ..cubicTo(
        size.width * 0.30,
        y + c,
        size.width * 0.70,
        y + c,
        size.width + 8,
        y,
      );
  }

  /// The wire and the particles on it. [dir] 1 runs the particles toward
  /// the wire's end, -1 toward its start.
  void _paintWire(
    Canvas canvas,
    Size size, {
    required double at,
    required double sag,
    required Color color,
    required double strength,
    required int dir,
  }) {
    final path = _wirePath(size, at, sag);
    // The wire under the light: faint, and a touch stronger while busy.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = color.withValues(alpha: 0.10 + 0.12 * strength),
    );
    final metric = path.computeMetrics(forceClosed: false).single;
    final count = 4 + (strength * 6).round();
    final speed = 0.35 + 1.05 * strength;
    for (var i = 0; i < count; i++) {
      var u = (_phase.value * speed + i / count) % 1;
      if (dir < 0) u = 1 - u;
      final pos =
          metric.getTangentForOffset(metric.length * u)?.position ??
          Offset.zero;
      // The particle swells and fades toward the wire's ends, so none is
      // ever cut off at the edge.
      final env = math.sin(math.pi * u);
      final a = (0.30 + 0.62 * strength) * env;
      canvas.drawCircle(
        pos,
        4.4 * (0.65 + 0.55 * env),
        Paint()..color = color.withValues(alpha: a * 0.30),
      );
      canvas.drawCircle(pos, 1.8, Paint()..color = color.withValues(alpha: a));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (rtl) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    // Download arrives at the user, upload leaves for the world; the two
    // wires hang on either side of the pill's words, a soft dip each.
    _paintWire(
      canvas,
      size,
      at: 0.26,
      sag: 0.12,
      color: downColor,
      strength: down.value,
      dir: -1,
    );
    _paintWire(
      canvas,
      size,
      at: 0.74,
      sag: 0.10,
      color: upColor,
      strength: up.value,
      dir: 1,
    );
    if (rtl) canvas.restore();
  }

  @override
  bool shouldRepaint(_DataFlowPainter old) =>
      old.downColor != downColor ||
      old.upColor != upColor ||
      old.rtl != rtl ||
      old.down != down ||
      old.up != up;
}
