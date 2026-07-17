import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'flipkart_nav_item.dart';

/// Floating pill bottom navigation — icon-only, drag + tap.
class FlipkartBottomNav extends StatefulWidget {
  const FlipkartBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.badgeCount = 0,
    this.accountInitial,
  });

  final List<FlipkartNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int badgeCount;
  final String? accountInitial;

  static const double barHeight = 58;
  static const double horizontalMargin = 22;
  static const double bottomGap = 14;

  @override
  State<FlipkartBottomNav> createState() => _FlipkartBottomNavState();
}

class _FlipkartBottomNavState extends State<FlipkartBottomNav> {
  double _indicatorIndex = 0;
  bool _dragging = false;
  int? _lastHapticTab;

  @override
  void initState() {
    super.initState();
    _indicatorIndex = widget.currentIndex.toDouble();
  }

  @override
  void didUpdateWidget(covariant FlipkartBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && oldWidget.currentIndex != widget.currentIndex) {
      _indicatorIndex = widget.currentIndex.toDouble();
    }
  }

  int _indexFromX(double x, double width) {
    final count = widget.items.length;
    if (count == 0 || width <= 0) return 0;
    final tabWidth = width / count;
    return ((x / tabWidth) - 0.5).round().clamp(0, count - 1);
  }

  void _commit(int index) {
    HapticFeedback.heavyImpact();
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final count = widget.items.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final barColor = isDark
        ? const Color(0xF51E293B)
        : const Color(0xF5FFFFFF);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE5E5E5);
    final activeColor = scheme.primary;
    final inactiveColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF878787);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        FlipkartBottomNav.horizontalMargin,
        0,
        FlipkartBottomNav.horizontalMargin,
        FlipkartBottomNav.bottomGap + bottomSafe,
      ),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Container(
            height: FlipkartBottomNav.barHeight,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final tabWidth = count == 0 ? 0.0 : width / count;
                final indicatorWidth = tabWidth * 0.78;
                final indicatorLeft =
                    (_indicatorIndex * tabWidth) +
                    (tabWidth - indicatorWidth) / 2;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final index = _indexFromX(details.localPosition.dx, width);
                    _indicatorIndex = index.toDouble();
                    setState(() {});
                    _commit(index);
                  },
                  onHorizontalDragStart: (_) {
                    HapticFeedback.heavyImpact();
                    _dragging = true;
                    _lastHapticTab = _indicatorIndex.round();
                  },
                  onHorizontalDragUpdate: (details) {
                    if (tabWidth <= 0) return;
                    final raw =
                        (details.localPosition.dx / tabWidth) - 0.5;
                    final next = raw.clamp(0.0, (count - 1).toDouble());
                    final region = next.round();
                    if (_lastHapticTab != region) {
                      _lastHapticTab = region;
                      HapticFeedback.heavyImpact();
                    }
                    setState(() => _indicatorIndex = next);
                  },
                  onHorizontalDragEnd: (details) {
                    _dragging = false;
                    final velocity = details.primaryVelocity ?? 0;
                    int target;
                    if (velocity.abs() >= 280) {
                      final dir = velocity < 0 ? 1 : -1;
                      target = (_indicatorIndex.round() + dir)
                          .clamp(0, count - 1);
                    } else {
                      target = _indicatorIndex.round().clamp(0, count - 1);
                    }
                    setState(() => _indicatorIndex = target.toDouble());
                    _commit(target);
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedPositioned(
                        duration: _dragging
                            ? Duration.zero
                            : const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        left: indicatorLeft,
                        top: (FlipkartBottomNav.barHeight - 40) / 2,
                        width: indicatorWidth,
                        height: 40,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.2 : 0.06,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < count; i++)
                            Expanded(
                              child: _NavTabSlot(
                                item: widget.items[i],
                                selected: widget.currentIndex == i,
                                badgeCount: widget.items[i].showBadge
                                    ? widget.badgeCount
                                    : 0,
                                accountInitial: widget.items[i].label ==
                                            'Account' &&
                                        widget.accountInitial != null
                                    ? widget.accountInitial
                                    : null,
                                activeColor: activeColor,
                                inactiveColor: inactiveColor,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTabSlot extends StatelessWidget {
  const _NavTabSlot({
    required this.item,
    required this.selected,
    required this.badgeCount,
    required this.activeColor,
    required this.inactiveColor,
    this.accountInitial,
  });

  final FlipkartNavItem item;
  final bool selected;
  final int badgeCount;
  final Color activeColor;
  final Color inactiveColor;
  final String? accountInitial;

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;
    final showAvatar =
        accountInitial != null && accountInitial!.trim().isNotEmpty;

    Widget iconChild;
    if (showAvatar) {
      iconChild = AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? activeColor.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? activeColor.withValues(alpha: 0.85)
                : inactiveColor.withValues(alpha: 0.55),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          accountInitial!,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1,
            color: color,
          ),
        ),
      );
    } else {
      iconChild = Icon(
        selected ? item.activeIcon : item.icon,
        size: 24,
        color: color,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            iconChild,
            if (item.showBadge && badgeCount > 0)
              Positioned(
                right: -7,
                top: -5,
                child: _NavBadge(count: badgeCount),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: BoxConstraints(
        minWidth: count > 9 ? 18 : 16,
        minHeight: 16,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? scheme.surface : Colors.white,
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onPrimary,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
