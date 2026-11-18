import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/extensions/context_extensions.dart';

/// Ultra-Compact Island Floating Bottom Navigation Dock with:
/// - 56px comfortable vertical capsule height with balanced breathing room
/// - Bespoke modern music glyphs (Discover, Explore, Vault, Offline) proportioned to 24px
/// - Zero permanent text labels under icons
/// - Zero pill boxes around the arriving text label (pure text floating and falling)
/// - Stylized borderless arriving typography with wide tracking (2.8)
/// - Snappy icon hop micro-interaction on tap
/// Strictly adheres to AGENTS.md Invariants 1-4.
class FloatingNavDock extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const FloatingNavDock({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  State<FloatingNavDock> createState() => _FloatingNavDockState();
}

class _FloatingNavDockState extends State<FloatingNavDock>
    with TickerProviderStateMixin {
  late final AnimationController _jumpController;
  late final Animation<double> _jumpAnimation;

  late final AnimationController _labelController;
  late final Animation<double> _labelFadeAnimation;
  late final Animation<double> _labelSlideAnimation;

  Timer? _labelTimer;
  int _lastTappedIndex = 0;

  static const List<_NavTabItem> _tabs = [
    _NavTabItem(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore_rounded,
      label: 'DISCOVER',
    ),
    _NavTabItem(
      icon: Icons.search_rounded,
      activeIcon: Icons.travel_explore_rounded,
      label: 'EXPLORE',
    ),
    _NavTabItem(
      icon: Icons.bookmarks_outlined,
      activeIcon: Icons.bookmarks_rounded,
      label: 'MY VAULT',
    ),
    _NavTabItem(
      icon: Icons.arrow_circle_down_outlined,
      activeIcon: Icons.arrow_circle_down_rounded,
      label: 'OFFLINE',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _lastTappedIndex = widget.selectedIndex;

    // 1. Icon Jump / Hop Animation
    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _jumpAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -7.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -7.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 55,
      ),
    ]).animate(_jumpController);

    // 2. Floating Jump Label Text Animation (No surrounding pill, pure typography)
    _labelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _labelFadeAnimation = CurvedAnimation(
      parent: _labelController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _labelSlideAnimation = Tween<double>(begin: 8.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _labelController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant FloatingNavDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _lastTappedIndex = widget.selectedIndex;
    }
  }

  @override
  void dispose() {
    _labelTimer?.cancel();
    _jumpController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _onTabPressed(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _lastTappedIndex = index;
    });

    // Trigger icon hop
    _jumpController.forward(from: 0.0);

    // Show floating jump text above dock
    _labelTimer?.cancel();
    _labelController.forward();

    // Hold for 3 seconds, then smoothly fall down
    _labelTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _labelController.reverse();
      }
    });

    widget.onTabSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = _tabs[_lastTappedIndex.clamp(0, _tabs.length - 1)];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: context.spacing.xs,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Floating Tab Arriving Text (Pure stylized typography with wide tracking, no pill)
            Positioned(
              top: -(context.spacing.lg + context.spacing.xs),
              child: AnimatedBuilder(
                animation: _labelController,
                builder: (context, child) {
                  if (_labelFadeAnimation.value == 0.0) {
                    return const SizedBox.shrink();
                  }
                  return Transform.translate(
                    offset: Offset(0, _labelSlideAnimation.value),
                    child: Opacity(
                      opacity: _labelFadeAnimation.value.clamp(0.0, 1.0),
                      child: Text(
                        activeTab.label,
                        style: context.typography.eyebrow.copyWith(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.8,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Ultra-Compact Outer Island Nav Bar with 56px Comfortable Vertical Height
            ClipRRect(
              borderRadius: context.radius.asBorderRadiusDock,
              child: Container(
                height: context.sizes.navDockHeight,
                padding: EdgeInsets.symmetric(
                  horizontal: context.spacing.sm,
                  vertical: context.spacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: context.colors.floatingDockSurface,
                  borderRadius: context.radius.asBorderRadiusDock,
                  border: Border.all(
                    color: context.colors.solidMatteBorder,
                    width: context.sizes.borderThin,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.oledBackground.withAlpha(180),
                      blurRadius: context.spacing.md,
                      offset: Offset(0, context.spacing.xs),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_tabs.length, (index) {
                    final tab = _tabs[index];
                    final isSelected = index == widget.selectedIndex;
                    final isJustTapped = index == _lastTappedIndex;

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _onTabPressed(index),
                      child: Container(
                        width: 52.0,
                        alignment: Alignment.center,
                        child: AnimatedBuilder(
                          animation: _jumpAnimation,
                          builder: (context, child) {
                            final offsetY =
                                isJustTapped ? _jumpAnimation.value : 0.0;
                            return Transform.translate(
                              offset: Offset(0, offsetY),
                              child: Icon(
                                isSelected ? tab.activeIcon : tab.icon,
                                size: context.sizes.iconMd,
                                color: isSelected
                                    ? context.colors.textPrimary
                                    : context.colors.textSecondary,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
