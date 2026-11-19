import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class MiskiNavItem {
  const MiskiNavItem({required this.icon, required this.selectedIcon, required this.label});
  final IconData icon;
  final IconData selectedIcon;

  /// Not shown (icons only); used for the tooltip and accessibility.
  final String label;
}

/// Floating rounded bottom bar whose top edge has a notch under the selected
/// tab. The selected icon sits in a circle inside that notch, and both slide
/// to the new tab when the selection changes.
class MiskiNavBar extends StatelessWidget {
  const MiskiNavBar({super.key, required this.items, required this.currentIndex, required this.onSelect});

  final List<MiskiNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const _barHeight = 68.0;
  static const _rise = 10.0; // how far the circle pokes above the bar
  static const _circle = 52.0;
  static const _duration = Duration(milliseconds: 450);
  static const _inset = 6.0;
  static const _topGap = 12.0;

  @override
  Widget build(BuildContext context) {
    final barColor = AppColors.surface;
    final shadow = AppColors.isDark ? Colors.black : AppColors.night.withValues(alpha: 0.18);

    // Sit almost on the bottom edge: instead of reserving the whole system
    // gesture/home-indicator area, keep just a small gap (6–12 px).
    final bottomGap = (MediaQuery.viewPaddingOf(context).bottom * 0.3).clamp(6.0, 12.0);

    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        // Top gap keeps the raised selection circle off the page content above.
        padding: EdgeInsets.fromLTRB(16, _topGap, 16, bottomGap),
        child: SizedBox(
          height: _barHeight + _rise,
          child: LayoutBuilder(
            builder: (context, box) {
              final slot = (box.maxWidth - 2 * _inset) / items.length;
              return TweenAnimationBuilder<double>(
                tween: Tween(end: currentIndex.toDouble()),
                duration: _duration,
                // Eases in and out so the circle glides instead of jumping.
                curve: Curves.easeInOutCubic,
                builder: (context, pos, _) {
                  final cx = _inset + slot * (pos + 0.5);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Bar with the notch at the (animated) selected position.
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _NotchedBarPainter(
                            color: barColor,
                            shadow: shadow,
                            top: _rise,
                            notchX: cx,
                            circleRadius: _circle / 2,
                          ),
                        ),
                      ),
                      // Unselected icons, centered in the bar.
                      Positioned(
                        left: _inset,
                        right: _inset,
                        bottom: 0,
                        height: _barHeight,
                        child: Row(
                          children: [
                            for (var i = 0; i < items.length; i++)
                              Expanded(
                                child: _Tab(
                                  item: items[i],
                                  selected: i == currentIndex,
                                  // Hidden while the circle passes over it.
                                  visibility: (pos - i).abs().clamp(0.0, 1.0),
                                  onTap: () => onSelect(i),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Selected icon in a circle sitting in the notch.
                      Positioned(
                        left: cx - _circle / 2,
                        top: 0,
                        child: IgnorePointer(
                          child: Container(
                            width: _circle,
                            height: _circle,
                            decoration: BoxDecoration(color: barColor, shape: BoxShape.circle),
                            child: AnimatedSwitcher(
                              duration: _duration,
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, a) => FadeTransition(
                                opacity: a,
                                child: ScaleTransition(scale: Tween(begin: 0.7, end: 1.0).animate(a), child: child),
                              ),
                              child: Icon(
                                items[currentIndex].selectedIcon,
                                key: ValueKey(currentIndex),
                                color: AppColors.accent,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.visibility, required this.onTap});
  final MiskiNavItem item;
  final bool selected;
  final double visibility;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: item.label,
    child: Semantics(
      label: item.label,
      selected: selected,
      button: true,
      // No ink splash/highlight: the moving circle is the only tap feedback.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.expand(
          child: Opacity(
            opacity: visibility,
            child: Icon(item.icon, size: 26, color: AppColors.textMuted),
          ),
        ),
      ),
    ),
  );
}

/// Rounded bar with a smooth bell-shaped notch cut into its top edge at
/// [notchX]. The notch is subtracted from the bar, so near the ends it simply
/// eats into the rounded corner, like the reference design.
class _NotchedBarPainter extends CustomPainter {
  _NotchedBarPainter({
    required this.color,
    required this.shadow,
    required this.top,
    required this.notchX,
    required this.circleRadius,
  });

  final Color color;
  final Color shadow;
  final double top; // y of the bar's flat top edge
  final double notchX;
  final double circleRadius;

  static const _corner = 22.0;
  static const _gap = 6.0; // space between the circle and the notch

  @override
  void paint(Canvas canvas, Size size) {
    final bar = Path()..addRRect(RRect.fromLTRBR(0, top, size.width, size.height, const Radius.circular(_corner)));

    final r = circleRadius + _gap; // notch radius around the circle
    final half = r * 1.9; // half width of the notch at the bar's top edge
    final bottom = circleRadius * 2 + _gap; // circle is drawn from y = 0
    final cx = notchX;

    final notch = Path()
      ..moveTo(cx - half, top - 40)
      ..lineTo(cx - half, top)
      ..cubicTo(cx - half * 0.45, top, cx - r * 1.15, bottom, cx, bottom)
      ..cubicTo(cx + r * 1.15, bottom, cx + half * 0.45, top, cx + half, top)
      ..lineTo(cx + half, top - 40)
      ..close();

    final shape = Path.combine(PathOperation.difference, bar, notch);
    canvas.drawShadow(shape, shadow, 8, false);
    canvas.drawPath(shape, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_NotchedBarPainter old) =>
      old.notchX != notchX || old.color != color || old.shadow != shadow || old.top != top;
}
