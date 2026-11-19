import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'motion.dart';
import 'widgets.dart' show StatusColors;

/// A destination of the [FloatingNavBar].
class FloatingNavDestination {
  const FloatingNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount,
  });

  /// Outlined while the tab rests, filled while it is the one.
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// A number in a badge over the icon (the accounts that need signing
  /// in); nothing when null or 0.
  final int? badgeCount;
}

/// The phone's navigation, the Pixel way: a capsule that floats above the
/// bottom edge with its shadow, over a blur of the page beneath it. The
/// chosen tab sits on a pill that glides to it, the icon swells with a
/// small bounce, and the tab it came to answers with a click the finger
/// hears.
class FloatingNavBar extends StatefulWidget {
  const FloatingNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });

  final List<FloatingNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsets margin;

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar> {
  void _select(int i) {
    if (i == widget.selectedIndex) return;
    if (Motion.on(context)) HapticFeedback.selectionClick();
    widget.onSelected(i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final n = widget.destinations.length;
    final safe = MediaQuery.paddingOf(context);
    return SafeArea(
      top: false,
      child: MotionEntrance(
        offset: const Offset(0, 26),
        fromScale: 0.98,
        duration: Motion.grand,
        child: Padding(
          padding: widget.margin.copyWith(
            bottom: widget.margin.bottom + safe.bottom,
          ),
          child: DecoratedBox(
            // The shadow rides outside the blur's clip, where it can
            // spread over the page beneath.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: dark
                      ? Colors.black.withValues(alpha: 0.35)
                      : const Color(0xFF12315E).withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: 66,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: (dark ? const Color(0xFF1C1C1E) : Colors.white)
                        .withValues(alpha: dark ? 0.82 : 0.82),
                  ),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.1)
                          : const Color(0xFF0B3B78).withValues(alpha: 0.07),
                    ),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: LayoutBuilder(
                      builder: (context, box) {
                        // The pill is one destination wide and glides along
                        // the capsule to the one chosen; the capsule mirrors
                        // itself in right-to-left languages.
                        final width = box.maxWidth;
                        final itemWidth = width / n;
                        final index = widget.selectedIndex.clamp(0, n - 1);
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: AnimatedAlign(
                                alignment: AlignmentDirectional(
                                  n == 1 ? 0 : -1 + 2 * index / (n - 1),
                                  0,
                                ),
                                duration: Motion.slow,
                                curve: Motion.emphasized,
                                child: FractionallySizedBox(
                                  widthFactor: 1 / n,
                                  heightFactor: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        color:
                                            theme.navigationBarTheme
                                                .indicatorColor ??
                                            scheme.primaryContainer,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Row(
                                children: [
                                  for (var i = 0; i < n; i++)
                                    Expanded(
                                      child: _Destination(
                                        destination: widget.destinations[i],
                                        selected: i == widget.selectedIndex,
                                        width: itemWidth,
                                        onTap: () => _select(i),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One tab of the capsule: the icon that swells when it is the one, its
/// name under it, and the badge, when there is one.
class _Destination extends StatelessWidget {
  const _Destination({
    required this.destination,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  final FloatingNavDestination destination;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // The restful tab sits in the muted ink; the chosen one, in the ink
    // of the pill it sits on.
    final idle = scheme.onSurfaceVariant;
    final chosen = scheme.onPrimaryContainer;
    final font = theme.textTheme.bodyMedium?.fontFamily;
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleSwitcher(
              duration: Motion.fast,
              child: Badge(
                key: ValueKey(selected),
                isLabelVisible: (destination.badgeCount ?? 0) > 0,
                label: Text('${destination.badgeCount}'),
                backgroundColor: StatusColors.bad,
                textStyle: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: font,
                ),
                child: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 23,
                  color: selected ? chosen : idle,
                ),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: font,
                fontSize: width < 170 ? 11 : 12,
                height: 1.05,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? chosen : idle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
