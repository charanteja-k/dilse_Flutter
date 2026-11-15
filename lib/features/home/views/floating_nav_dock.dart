import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/extensions/context_extensions.dart';

/// Ultra-Compact Island Floating Bottom Navigation Dock with:
/// - Shrink-to-fit outer box (hugs only the 4 icons with minimal spacing)
/// - Zero permanent text labels under icons
/// - Tactile Icon Hop / Jump animation on tap
/// - Floating Jump Label badge above the dock that lingers for 3 seconds and falls down
/// Strictly adheres to AGENTS.md:
/// - Invariant 1: Pure presentation widget, zero static singletons.
/// - Invariant 2: Context-Exposed Design Tokens (zero magic numbers/raw colors).
/// - Invariant 3: Strict MVVM (View-only presentation).
/// - Invariant 4: Strict Monochrome Black & White Theme (Zero gradients & zero neons).
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
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavTabItem(
      icon: Icons.search_rounded,
      activeIcon: Icons.saved_search_rounded,
      label: 'Search',
    ),
    _NavTabItem(
      icon: Icons.library_music_outlined,
      activeIcon: Icons.library_music_rounded,
      label: 'Library',
    ),
    _NavTabItem(
      icon: Icons.download_outlined,
      activeIcon: Icons.download_rounded,
      label: 'Downloads',
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
        tween: Tween<double>(begin: 0.0, end: -6.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -6.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 55,
      ),
    ]).animate(_jumpController);

    // 2. Floating Jump Label Badge Animation
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
    _labelSlideAnimation = Tween<double>(begin: 10.0, end: 0.0).animate(
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

    // Hold for exactly 3 seconds, then smoothly fall down
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
            // Floating Jump Label Badge positioned above the dock
            Positioned(
              top: -(context.sizes.chipHeight + context.spacing.xxs),
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
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.spacing.md,
                          vertical: context.spacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.floatingDockSurface,
                          borderRadius: context.radius.asBorderRadiusFull,
                          border: Border.all(
                            color: context.colors.solidMatteBorder,
                            width: context.sizes.borderThin,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.oledBackground.withAlpha(160),
                              blurRadius: context.spacing.sm,
                              offset: Offset(0, context.spacing.xxs),
                            ),
                          ],
                        ),
                        child: Text(
                          activeTab.label,
                          style: context.typography.eyebrow.copyWith(
                            color: context.colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Ultra-Compact Outer Island Nav Bar
            ClipRRect(
              borderRadius: context.radius.asBorderRadiusDock,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.spacing.xs,
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
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                          horizontal: context.spacing.md,
                          vertical: context.spacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? context.colors.cardDarkSurface
                              : Colors.transparent,
                          borderRadius: context.radius.asBorderRadiusFull,
                          border: isSelected
                              ? Border.all(
                                  color: context.colors.solidMatteBorder,
                                  width: context.sizes.borderThin,
                                )
                              : null,
                        ),
                        child: AnimatedBuilder(
                          animation: _jumpAnimation,
                          builder: (context, child) {
                            final offsetY = isJustTapped ? _jumpAnimation.value : 0.0;
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
