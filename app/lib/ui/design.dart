import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'effects.dart';
import 'format.dart';
import 'motion.dart';
import 'widgets.dart' show StatusColors, delayColor;

/// The Fali design language, built once and used by every screen: the
/// pure black night with its neutral gray cards, the electric blue, the
/// 26-pixel rounded cards, the pill chips, the capsule power button, and
/// the dotted arc dial. Every color asks the app's theme, so light and
/// dark come free.

/// The surfaces the approved design named, behind the theme's tokens.
abstract final class Dali {
  // Dark: the night is pure black, the cards neutral grays — no blue
  // under it, the way the approved sample wears it.
  static const bgDark = Color(0xFF000000);
  static const surfaceDark = Color(0xFF1C1C1E);
  static const surface2Dark = Color(0xFF2C2C2E);
  static const surface3Dark = Color(0xFF3A3A3C);
  static const navDark = Color(0xFF0E0E10);
  static const onDark = Color(0xFFF2F2F7);
  static const onVarDark = Color(0xFF8E8E93);

  // Light.
  static const bgLight = Color(0xFFF5F8FE);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surface2Light = Color(0xFFEDF2FC);
  static const surface3Light = Color(0xFFE2EAF8);
  static const onLight = Color(0xFF1A1D24);
  static const onVarLight = Color(0xFF5B6474);

  // The accents.
  static const primary = Color(0xFF2D7DFF);
  static const onPrimary = Color(0xFFFFFFFF);
  static const good = Color(0xFF34A853);
  static const bad = Color(0xFFEA4335);
  static const amber = Color(0xFFFBBC04);

  /// The page's second surface, where chips and search fields sit.
  static Color surface2(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHigh;

  /// The third surface, for a control resting on [surface2].
  static Color surface3(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;

  /// The ink that stands back (labels, captions).
  static Color onVar(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  /// The card's hairline, inside and out.
  static Color hairline(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFF0B3B78).withValues(alpha: 0.07);

  /// A color's wash, the way the design tints chips and tiles.
  static Color wash(Color c, bool dark) =>
      c.withValues(alpha: dark ? 0.16 : 0.11);
}

/// The card every screen is built from: 26-pixel rounded corners, the
/// theme's surface under frosted glass — the pane the page's lights tint,
/// with a rim that catches the light at its top edge. Lists carry it
/// without the blur: the glass reads there too, and the scrolling keeps
/// its smoothness.
class DaliCard extends StatelessWidget {
  const DaliCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.radius = 26,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: padding,
      radius: radius,
      color: color,
      onTap: onTap,
      child: child,
    );
  }
}

/// A small label above a section ("Recently connected"), in the muted ink.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 2, 6, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.labelLarge?.copyWith(
                color: Dali.onVar(context),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The delay as the design's pill: the number and "ms" in its color's
/// wash. Grey while it is not known, and a spinner while it is measured.
/// The digits follow the language: Persian numerals in Persian, Latin
/// everywhere else, so the whole page reads in one hand.
class PingChip extends StatelessWidget {
  const PingChip({
    super.key,
    required this.ms,
    this.testing = false,
    this.compact = false,
  });

  /// The delay in milliseconds; null for "not measured".
  final int? ms;
  final bool testing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = testing ? Dali.onVar(context) : delayColor(ms ?? 1000);
    final persian = AppLocalizations.of(context).localeName == 'fa';
    final number = ms == null ? null : '${ms!}';
    final text = testing
        ? ''
        : number == null
        ? '—'
        : '${persian ? persianDigits(number) : number}ms';
    final style = theme.textTheme.labelMedium?.copyWith(
      color: color,
      fontWeight: FontWeight.w700,
      fontFeatures: const [],
    );
    return AnimatedContainer(
      duration: Motion.normal,
      curve: Motion.emphasized,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 2 : 3.5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.16 : 0.10,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: ScaleSwitcher(
        child: testing
            ? SizedBox.square(
                key: const ValueKey('t'),
                dimension: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: Dali.onVar(context),
                ),
              )
            : Text(text, key: ValueKey(text), style: style),
      ),
    );
  }
}

/// One of the three live chips on the home page: a colored icon tile, the
/// reading in bold, and the name under it in the muted ink. The reading
/// scales to its box instead of cutting off, so a narrow phone reads the
/// whole of it.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.unit,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(9, 9, 7, 9),
      decoration: BoxDecoration(
        color: Dali.surface2(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Dali.hairline(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              color: Dali.wash(color, dark),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The reading: it shrinks to fit rather than cut off.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text.rich(
                    TextSpan(
                      text: value,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [],
                      ),
                      children: [
                        if (unit != null)
                          TextSpan(
                            text: ' ${unit!}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Dali.onVar(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Dali.onVar(context),
                    fontWeight: FontWeight.w500,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The round search field of the servers page. Under the finger's focus
/// it lights: a soft blue halo breathes out of it while the user types.
class SearchField extends StatefulWidget {
  const SearchField({super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: Motion.fast,
      curve: Motion.emphasized,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          if (_focus.hasFocus)
            BoxShadow(
              color: Dali.primary.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.40 : 0.28,
              ),
              blurRadius: 20,
            ),
        ],
      ),
      child: TextField(
        focusNode: _focus,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.done,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded, size: 21),
          hintText: widget.hint,
          isDense: true,
          filled: true,
          fillColor: Dali.surface2(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: Dali.primary, width: 1.6),
          ),
        ),
      ),
    );
  }
}

/// The connect pill of a server row: "اتصال" while it waits, a spinner
/// while the choice saves, and the green word on the chosen one.
class ConnectPill extends StatelessWidget {
  const ConnectPill({
    super.key,
    required this.label,
    required this.selected,
    required this.busy,
    this.onTap,
  });

  final String label;
  final bool selected;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final color = selected ? StatusColors.good : Dali.primary;
    return PressScale(
      onTap: busy || onTap == null ? null : onTap,
      amount: 0.94,
      // Soft depth: the pill swells a little out of its row, and the face
      // glides between the blue and the connected green.
      child: SoftDepth(
        color: selected ? Dali.wash(StatusColors.good, dark) : color,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: ScaleSwitcher(
            duration: Motion.fast,
            child: busy
                ? SizedBox.square(
                    key: const ValueKey('busy'),
                    dimension: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: selected ? StatusColors.good : Colors.white,
                    ),
                  )
                : Text(
                    label,
                    key: const ValueKey('label'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected ? StatusColors.good : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// One server in the lists of the servers page: the flag, the name and
/// its city, the delay, and the connect pill. The chosen one wears green.
class ServerTile extends StatelessWidget {
  const ServerTile({
    super.key,
    required this.leading,
    required this.name,
    this.subtitle,
    required this.ms,
    this.testing = false,
    required this.selected,
    required this.busy,
    required this.connectLabel,
    required this.connectedLabel,
    required this.onTap,
  });

  /// Something before the name: the country's flag, or an icon for a
  /// choice that is not a country.
  final Widget leading;
  final String name;
  final String? subtitle;
  final int? ms;
  final bool testing;
  final bool selected;
  final bool busy;
  final String connectLabel;
  final String connectedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final edge = selected
        ? StatusColors.good.withValues(alpha: dark ? 0.55 : 0.45)
        : Dali.hairline(context);
    return PressScale(
      onTap: onTap,
      amount: 0.985,
      child: AnimatedContainer(
        duration: Motion.normal,
        curve: Motion.emphasized,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 10, 10),
        decoration: BoxDecoration(
          // The glass tint at rest — the page's lights pass through it —
          // and the state's wash on the chosen one.
          color: selected
              ? Dali.wash(StatusColors.good, dark)
              : theme.colorScheme.surfaceContainer.withValues(
                  alpha: GlassCard.fillAlpha(dark),
                ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: edge),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The name may take two lines: a long country's name
                  // wraps cleanly rather than losing its tail. The card
                  // grows with it.
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      height: 1.25,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        height: 1.25,
                        color: Dali.onVar(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            PingChip(ms: ms, testing: testing, compact: true),
            const SizedBox(width: 8),
            ConnectPill(
              label: selected ? connectedLabel : connectLabel,
              selected: selected,
              busy: busy,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// A choice that is not a country (recommended, fastest): an icon tile
/// instead of the flag, and a check instead of the pill.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.icon,
    required this.name,
    required this.subtitle,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String name;
  final String subtitle;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return PressScale(
      onTap: onTap,
      amount: 0.985,
      child: AnimatedContainer(
        duration: Motion.normal,
        curve: Motion.emphasized,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: selected
              ? Dali.wash(Dali.primary, dark)
              : theme.colorScheme.surfaceContainer.withValues(
                  alpha: GlassCard.fillAlpha(dark),
                ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? Dali.primary.withValues(alpha: dark ? 0.55 : 0.45)
                : Dali.hairline(context),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 30,
              decoration: BoxDecoration(
                color: Dali.wash(Dali.primary, dark),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                size: 17,
                color: dark ? const Color(0xFFD6E4FF) : const Color(0xFF0B3B78),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      height: 1.25,
                      color: Dali.onVar(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ScaleSwitcher(
              child: busy
                  ? const SizedBox.square(
                      key: ValueKey('b'),
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      key: const ValueKey('s'),
                      size: 20,
                      color: selected
                          ? Dali.primary
                          : theme.colorScheme.outline,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dotted arc dial of the details and the speed test: a track of
/// round points from the lower left over the top to the lower right, the
/// reading's blue arc over it, a green bead where it ends, and the number
/// in the middle.
class ArcDial extends StatelessWidget {
  const ArcDial({
    super.key,
    required this.fraction,
    required this.valueText,
    required this.unitText,
    this.caption,
    this.size = const Size(252, 172),
    this.color,
  });

  /// The reading, 0 to 1 of the arc.
  final double fraction;
  final String valueText;
  final String unitText;

  /// A word under the unit ("measured so far").
  final String? caption;
  final Size size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = fraction.clamp(0.0, 1.0);
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: shown),
              duration: Motion.slow,
              curve: Motion.emphasized,
              builder: (context, v, _) => CustomPaint(
                painter: _DialPainter(
                  fraction: v,
                  color: color ?? Dali.primary,
                  track: Dali.onVar(context).withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.55 : 0.45,
                  ),
                  end: StatusColors.good,
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                valueText,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [],
                ),
              ),
              Text(
                unitText,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Dali.onVar(context),
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 2),
                Text(
                  caption!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Dali.onVar(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.end,
  });

  final double fraction;
  final Color color;
  final Color track;
  final Color end;

  /// The arc opens at the bottom: from the lower left, over the top, to
  /// the lower right, with the gap the number sits in.
  static const _start = 140 * math.pi / 180;
  static const _sweep = 260 * math.pi / 180;
  static const _dots = 30;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.62);
    final radius = math.min(size.width, size.height) / 2 - 8;
    Offset at(double a) => center + Offset(math.cos(a), math.sin(a)) * radius;

    // The track: round points, evenly spread.
    final paint = Paint()
      ..color = track
      ..strokeWidth = 4.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i <= _dots; i++) {
      canvas.drawCircle(at(_start + _sweep * i / _dots), 2.1, paint);
    }

    // The reading: the arc drawn twice — a soft glow under a crisp
    // stroke — then its green bead at the end.
    if (fraction > 0) {
      final arc = Rect.fromCircle(center: center, radius: radius);
      final sweep = _sweep * fraction;
      final soft = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawArc(arc, _start, sweep, false, soft);
      canvas.drawArc(
        arc,
        _start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.4
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(at(_start + sweep), 3.6, Paint()..color = end);
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}

/// One line of the details card: the name in the muted ink and the value
/// in bold, as the design's rows.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Dali.onVar(context),
            ),
          ),
          const Spacer(),
          value,
        ],
      ),
    );
  }
}

/// The bar of the details card ("data moved"): its fill glides between
/// readings, the label and the number above it.
class LoadBar extends StatelessWidget {
  const LoadBar({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    this.color = StatusColors.good,
  });

  final String label;
  final String value;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Dali.onVar(context),
                ),
              ),
            ),
            Text(
              value,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [],
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: fraction.clamp(0.0, 1.0)),
            duration: Motion.slow,
            curve: Motion.emphasized,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 7,
              backgroundColor: Dali.surface3(context),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}

/// A home problem in its own tinted card: red for an error, amber for a
/// warning, with a word for what to do and, when it helps, buttons.
class ProblemCard extends StatelessWidget {
  const ProblemCard({
    super.key,
    required this.text,
    required this.color,
    required this.icon,
    this.actions = const <Widget>[],
    this.tooltip = '',
  });

  final String text;
  final Color color;
  final IconData icon;
  final List<Widget> actions;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 8),
        decoration: BoxDecoration(
          color: Dali.wash(color, dark),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (actions.isNotEmpty)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(children: actions),
              ),
          ],
        ),
      ),
    );
  }
}

/// A small tinted tile with an icon, as the settings hub's leading mark.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 36,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Dali.wash(color, dark),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.58, color: color),
    );
  }
}

/// A value box of the "last test" card: the name in the muted ink, the
/// number under it in bold.
class ValueBox extends StatelessWidget {
  const ValueBox({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: Dali.surface2(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Dali.onVar(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [],
            ),
          ),
        ],
      ),
    );
  }
}

/// The rate in megabits a second from bytes a second, for the dials.
double mbpsFrom(int bytesPerSecond) => bytesPerSecond * 8 / 1e6;

/// Grows a dial's top to [v]'s next kind round number, so the arc stays
/// inside while the top keeps meaning something. `math.pow` answers an
/// int while both its arguments are ints, so the base goes in as a
/// double — an `as double` on the int it returns would throw every time,
/// and the page that called it would show as grey nothing.
double niceCeil(double v) {
  final e = math
      .pow(10.0, (math.log(math.max(v, 1)) / math.ln10).floor())
      .toDouble();
  for (final m in const [1, 1.5, 2, 3, 4, 5, 7.5, 10]) {
    if (m * e >= v) return m * e;
  }
  return 10 * e;
}
