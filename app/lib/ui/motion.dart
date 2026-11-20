import 'dart:async' show Timer;
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Whether the repeating effects (breathes, sweeps, drifts) may run here:
/// the system allows motion and the platform pauses its frames with the
/// app in the background, so nothing ticks in a tray with the window
/// hidden. The computer keeps every one-shot animation; only the endless
/// ones stay off there, where they would cost a core while nobody looks.
bool repeatingEffectsOn(BuildContext context) =>
    Motion.on(context) && (Platform.isAndroid || Platform.isIOS);

/// The app's motion system: the durations and curves of Google's Material
/// You motion, and the widgets that play them. One-shots everywhere (a
/// page's entrance, a number that counts, a state that slides in) so a
/// still screen costs no frames.
abstract final class Motion {
  // Durations, from Material's own tokens.
  static const instant = Duration(milliseconds: 100);
  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 400);
  static const grand = Duration(milliseconds: 560);

  /// A breath of the connected state, between color shifts.
  static const breathe = Duration(milliseconds: 2800);

  /// The stagger between neighbors in a list of entrances.
  static const staggerStep = Duration(milliseconds: 42);

  // Material's emphasized easing: fast out, gentle settle.
  static const Cubic emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Cubic emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Cubic emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  /// A settle with a small overshoot, for things that snap into place.
  static const Cubic pop = Cubic(0.34, 1.4, 0.64, 1.0);

  /// Whether the running effects may run: the user asked the system for
  /// less motion.
  static bool on(BuildContext context) =>
      !MediaQuery.of(context).disableAnimations;
}

/// A one-shot entrance: the child fades in, rises from [offset] (in
/// pixels) and, with [fromScale], grows from a little smaller. Plays once
/// when built, after [delay]; a rebuild does not replay it.
class MotionEntrance extends StatefulWidget {
  const MotionEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 20),
    this.fromScale,
    this.duration = Motion.normal,
    this.curve = Motion.emphasizedDecelerate,
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  /// Starts this much smaller and grows to full; 1 for none.
  final double? fromScale;
  final Duration duration;
  final Curve curve;

  @override
  State<MotionEntrance> createState() => _MotionEntranceState();
}

class _MotionEntranceState extends State<MotionEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _c,
    curve: widget.curve,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curve.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The system asked for less motion: what it becomes, at once.
    if (!Motion.on(context)) {
      _c.value = 1;
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final t = _curve.value;
        final rest = 1 - t;
        Widget out = Transform.translate(
          offset: Offset(widget.offset.dx * rest, widget.offset.dy * rest),
          child: child,
        );
        if (widget.fromScale != null) {
          out = Transform.scale(
            scale: widget.fromScale! + (1 - widget.fromScale!) * t,
            child: out,
          );
        }
        return Opacity(opacity: t, child: out);
      },
      child: widget.child,
    );
  }
}

/// The children enter one after another, [step] apart; beyond half a
/// second the step shrinks, so a long list still lands within a beat.
class MotionStagger extends StatelessWidget {
  const MotionStagger({
    super.key,
    required this.children,
    this.step = Motion.staggerStep,
    this.base = Duration.zero,
    this.offset = const Offset(0, 20),
    this.fromScale,
    this.duration = Motion.normal,
    this.padBetween,
  });

  final List<Widget> children;
  final Duration step;
  final Duration base;
  final Offset offset;
  final double? fromScale;
  final Duration duration;

  /// Space between the children, instead of their own spacers.
  final double? padBetween;

  @override
  Widget build(BuildContext context) {
    final n = children.length;
    final clamped = n > 1
        ? Duration(microseconds: step.inMicroseconds.clamp(0, 500000 ~/ n))
        : step;
    final list = <Widget>[
      for (var i = 0; i < n; i++)
        MotionEntrance(
          delay: base + clamped * i,
          offset: offset,
          fromScale: fromScale,
          duration: duration,
          child: children[i],
        ),
    ];
    if (padBetween == null) return Column(children: list);
    return Column(
      children: [
        for (var i = 0; i < list.length; i++) ...[
          if (i > 0) SizedBox(height: padBetween),
          list[i],
        ],
      ],
    );
  }
}

/// A wrapper that presses down under the finger and springs back up:
/// [amount] of itself while held. With [haptic], a click the finger hears.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.amount = 0.96,
    this.haptic = false,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double amount;
  final bool haptic;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _held = false;

  void _set(bool held) {
    if (_held == held) return;
    setState(() => _held = held);
    if (held && widget.haptic && Motion.on(context)) {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The system asked for less motion: no press animation, but the tap
    // itself still has to answer — some controls (the power capsule, the
    // servers' connect pills) carry no other handler of their own.
    if (!Motion.on(context)) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.child,
      );
    }
    return GestureDetector(
      // Opaque: the whole control answers, not only its painted children
      // (the power capsule's pill is mostly empty glass around the knob).
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => _set(true) : null,
      onTapUp: widget.enabled ? (_) => _set(false) : null,
      onTapCancel: widget.enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _held ? widget.amount : 1,
        duration: Motion.fast,
        curve: _held ? Motion.emphasizedAccelerate : Motion.pop,
        child: widget.child,
      ),
    );
  }
}

/// Expanding rings behind a control, for the state that is alive: while
/// connected, the switch breathes. [enabled] switches it off (and with
/// it, the frames it costs). Two rings, half a cycle apart.
class PulseHalo extends StatefulWidget {
  const PulseHalo({
    super.key,
    required this.color,
    required this.size,
    required this.enabled,
    this.rings = 2,
    this.period = Motion.breathe,
    this.maxSpread = 0.55,
  });

  final Color color;
  final double size;
  final bool enabled;
  final int rings;
  final Duration period;
  final double maxSpread;

  @override
  State<PulseHalo> createState() => _PulseHaloState();
}

class _PulseHaloState extends State<PulseHalo>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PulseHalo old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled ||
        old.period != widget.period ||
        old.rings != widget.rings) {
      _sync();
    }
  }

  void _sync() {
    final on = widget.enabled && repeatingEffectsOn(context);
    if (on && _c == null) {
      final c = AnimationController(vsync: this, duration: widget.period);
      _c = c..repeat();
    } else if (!on && _c != null) {
      _c!.dispose();
      _c = null;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: c,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _HaloPainter(
            color: widget.color,
            progress: c.value,
            rings: widget.rings,
            maxSpread: widget.maxSpread,
          ),
        ),
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter({
    required this.color,
    required this.progress,
    required this.rings,
    required this.maxSpread,
  });

  final Color color;
  final double progress;
  final int rings;
  final double maxSpread;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.shortestSide / 2;
    final paint = Paint()..style = PaintingStyle.stroke;
    for (var i = 0; i < rings; i++) {
      // Each ring runs the cycle, offset a share of it.
      final t = (progress + i / rings) % 1;
      final eased = Curves.easeOutCubic.transform(t);
      final radius = base * (1 + maxSpread * eased);
      paint.strokeWidth = 10 * (1 - eased);
      paint.color = color.withValues(alpha: 0.28 * (1 - eased));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_HaloPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.rings != rings ||
      old.maxSpread != maxSpread;
}

/// A band of light that sweeps across its child, for the wait that works:
/// the pill while the app is connecting. Runs only while [enabled].
class ShimmerSweep extends StatefulWidget {
  const ShimmerSweep({
    super.key,
    required this.child,
    required this.enabled,
    this.color = Colors.white,
    this.period = const Duration(milliseconds: 1600),
  });

  final Widget child;
  final bool enabled;
  final Color color;
  final Duration period;

  @override
  State<ShimmerSweep> createState() => _ShimmerSweepState();
}

class _ShimmerSweepState extends State<ShimmerSweep>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ShimmerSweep old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled || old.period != widget.period) _sync();
  }

  void _sync() {
    final on = widget.enabled && repeatingEffectsOn(context);
    if (on && _c == null) {
      final c = AnimationController(vsync: this, duration: widget.period);
      _c = c..repeat();
    } else if (!on && _c != null) {
      _c!.dispose();
      _c = null;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return widget.child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: c,
                builder: (context, _) {
                  // The band travels from before the start to past the end,
                  // most of the time waiting off-stage.
                  final t = c.value;
                  final width = MediaQuery.widthOf(context);
                  final x = (t * 2.2 - 0.6) * width;
                  return Transform.translate(
                    offset: Offset(x, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Transform.rotate(
                        angle: 0.5,
                        child: Container(
                          width: 44,
                          height: 200,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                widget.color.withValues(alpha: 0),
                                widget.color.withValues(alpha: 0.22),
                                widget.color.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft round light that drifts slowly, with the state's color: the
/// home page's sky is never quite still on the phone. Static on the
/// computer, as every repeating effect there.
class DriftingGlow extends StatefulWidget {
  const DriftingGlow({
    super.key,
    required this.color,
    required this.size,
    required this.alpha,
    this.drift = 12,
    this.period = const Duration(seconds: 11),
  });

  final Color color;
  final double size;
  final double alpha;

  /// How far it wanders, in pixels.
  final double drift;
  final Duration period;

  @override
  State<DriftingGlow> createState() => _DriftingGlowState();
}

class _DriftingGlowState extends State<DriftingGlow>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(DriftingGlow old) {
    super.didUpdateWidget(old);
    if (old.period != widget.period) _sync();
  }

  void _sync() {
    if (repeatingEffectsOn(context) && _c == null) {
      final c = AnimationController(vsync: this, duration: widget.period);
      _c = c..repeat();
    } else if (!repeatingEffectsOn(context) && _c != null) {
      _c!.dispose();
      _c = null;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            widget.color.withValues(alpha: widget.alpha),
            widget.color.withValues(alpha: 0),
          ],
        ),
      ),
    );
    final c = _c;
    if (c == null) return IgnorePointer(child: glow);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: c,
        // A lissajous wander: each axis a sine, out of phase.
        builder: (context, _) {
          final t = c.value * 2 * math.pi;
          return Transform.translate(
            offset: Offset(
              widget.drift * math.sin(t),
              widget.drift * math.sin(t + 1.1),
            ),
            child: glow,
          );
        },
      ),
    );
  }
}

/// A number that counts to its new value, in words made by [format]: the
/// data used, a percentage. The text slides up a little as it changes, so
/// the eye finds it.
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = Motion.normal,
    this.curve = Motion.emphasized,
  });

  final double value;
  final String Function(double value) format;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value),
    duration: duration,
    curve: curve,
    builder: (context, v, _) => SlideFadeSwitcher(
      // The key: a change of the words, not of the count, slides it.
      key: ValueKey(format(v)),
      duration: Motion.fast,
      child: Text(format(v), style: style),
    ),
  );
}

/// A circular progress that fills smoothly to its value, with a soft
/// round cap.
class AnimatedArc extends StatelessWidget {
  const AnimatedArc({
    super.key,
    required this.value,
    required this.color,
    required this.track,
    this.stroke = 6,
    this.child,
    this.duration = Motion.slow,
  });

  final double value;
  final Color color;
  final Color track;
  final double stroke;
  final Widget? child;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.clamp(0.0, 1.0)),
    duration: duration,
    curve: Motion.emphasized,
    builder: (context, v, _) => CustomPaint(
      painter: _ArcPainter(
        value: v,
        color: color,
        track: track,
        stroke: stroke,
      ),
      child: child,
    ),
  );
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double value;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * value,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

/// A child that swaps with a slide up and a fade, Material's shared axis
/// on the y axis: the state under the switch, a page's title.
class SlideFadeSwitcher extends StatelessWidget {
  const SlideFadeSwitcher({
    super.key,
    required this.child,
    this.duration = Motion.normal,
    this.distance = 14,
  });

  final Widget child;
  final Duration duration;
  final double distance;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: duration,
    switchInCurve: Motion.emphasizedDecelerate,
    switchOutCurve: Motion.emphasizedAccelerate,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, distance / 40),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: child,
  );
}

/// An icon that swaps with a scale and a fade: outlined to filled, the
/// power icon to the spinner.
class ScaleSwitcher extends StatelessWidget {
  const ScaleSwitcher({
    super.key,
    required this.child,
    this.duration = Motion.fast,
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: duration,
    switchInCurve: Motion.pop,
    switchOutCurve: Motion.emphasizedAccelerate,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(scale: animation, child: child),
    ),
    child: child,
  );
}

/// A page the shell pushes slides in from the reading direction's side,
/// grows from a little smaller, and fades in, Material's shared axis x.
/// Everything rides the page's own animation, so the page rests at full
/// size and full opacity: a scale that followed the route below would
/// leave it 96% wide for its whole life, the window's black showing
/// around it on every side.
class FaliRoute<T> extends PageRouteBuilder<T> {
  FaliRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: Motion.slow,
        reverseTransitionDuration: Motion.normal,
        pageBuilder: (context, animation, secondary) => builder(context),
        transitionsBuilder: (context, animation, secondary, child) {
          final rtl = Directionality.of(context) == TextDirection.rtl;
          final sign = rtl ? -1.0 : 1.0;
          final inCurve = CurvedAnimation(
            parent: animation,
            curve: Motion.emphasizedDecelerate,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(sign * 0.16, 0),
              end: Offset.zero,
            ).animate(inCurve),
            child: FadeTransition(
              opacity: inCurve,
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(inCurve),
                child: child,
              ),
            ),
          );
        },
      );
}

/// A dialog that grows from a little smaller and fades in, instead of
/// Material's plain fade.
Future<T?> showFaliDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  RouteSettings? routeSettings,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  barrierColor:
      barrierColor ??
      Theme.of(context).colorScheme.scrim.withValues(alpha: 0.45),
  barrierLabel:
      barrierLabel ??
      MaterialLocalizations.of(context).modalBarrierDismissLabel,
  routeSettings: routeSettings,
  transitionDuration: Motion.normal,
  pageBuilder: (context, animation, secondary) => builder(context),
  transitionBuilder: (context, animation, secondary, child) {
    final inCurve = CurvedAnimation(parent: animation, curve: Motion.pop);
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Motion.emphasized),
      child: ScaleTransition(
        scale: Tween(begin: 0.9, end: 1.0).animate(inCurve),
        child: child,
      ),
    );
  },
);

/// A banner that drops in from its top, and slides back out when it goes.
class DropInBanner extends StatefulWidget {
  const DropInBanner({super.key, required this.child, required this.visible});

  final Widget child;
  final bool visible;

  @override
  State<DropInBanner> createState() => _DropInBannerState();
}

class _DropInBannerState extends State<DropInBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.slow,
    value: widget.visible ? 1 : 0,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _c,
    curve: Motion.emphasizedDecelerate,
  );

  @override
  void didUpdateWidget(DropInBanner old) {
    super.didUpdateWidget(old);
    if (widget.visible != old.visible) {
      widget.visible ? _c.forward() : _c.reverse();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Motion.on(context)) {
      return widget.visible ? widget.child : const SizedBox.shrink();
    }
    return SizeTransition(
      sizeFactor: _curve,
      // The drop-in pins to the top edge (the old axisAlignment: -1).
      alignment: Alignment(-1.0, -1.0),
      child: FadeTransition(opacity: _curve, child: widget.child),
    );
  }
}

/// A child that arrives and leaves with the page's own easing: the room
/// it takes grows and closes smoothly (the cards under it never jump),
/// while the child itself fades in, sliding down a breath from above —
/// and slides back up as it goes. The [tag] identifies the content: when
/// it changes, the new content crosses with the old in the same motion,
/// so a banner that swaps its words swaps them the soft way.
class MotionAppear extends StatelessWidget {
  const MotionAppear({
    super.key,
    required this.visible,
    required this.child,
    this.tag = 'on',
    this.duration = Motion.normal,
  });

  final bool visible;
  final Widget child;

  /// The content's identity, stable across rebuilds (a version's word, a
  /// notice's key): the crossing plays when it changes, not when the
  /// page merely rebuilds.
  final Object tag;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final on = Motion.on(context);
    return AnimatedSize(
      duration: duration,
      curve: on ? Motion.emphasized : Curves.linear,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Motion.emphasizedDecelerate,
        switchOutCurve: Motion.emphasizedAccelerate,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.16),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: visible
            ? KeyedSubtree(key: ValueKey(tag), child: child)
            : const SizedBox.shrink(key: ValueKey('off')),
      ),
    );
  }
}
