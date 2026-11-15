import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/widgets/dilse_notification.dart';

/// Apple-Style Glassmorphic Floating Bottom Navigation Dock with Sliding Indicator.
/// Adheres strictly to AGENTS.md:
/// - Invariant 1: Stateless presentation, zero static singletons.
/// - Invariant 2: Context-Exposed Design Tokens (Strictly Zero Magic Numbers).
/// - Invariant 3: View-only UI code, zero business logic.
class FloatingNavDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const FloatingNavDock({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = const [
      _NavTabItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
        isEnabled: true,
      ),
      _NavTabItem(
        icon: Icons.search_rounded,
        activeIcon: Icons.saved_search_rounded,
        label: 'Search',
        isEnabled: true,
      ),
      _NavTabItem(
        icon: Icons.library_music_outlined,
        activeIcon: Icons.library_music_rounded,
        label: 'Library',
        isEnabled: false,
      ),
      _NavTabItem(
        icon: Icons.download_outlined,
        activeIcon: Icons.download_rounded,
        label: 'Downloads',
        isEnabled: false,
      ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: context.spacing.md,
          right: context.spacing.md,
          bottom: context.spacing.xs,
        ),
        child: ClipRRect(
          borderRadius: context.radius.asBorderRadiusDock,
          child: Container(
            height: context.sizes.navDockHeight,
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing.xs,
              vertical: context.spacing.xs,
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
                  color: context.colors.oledBackground.withAlpha(160),
                  blurRadius: context.spacing.md,
                  offset: Offset(0, context.spacing.xs),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth = constraints.maxWidth / tabs.length;
                return Stack(
                  children: [
                    // Smooth sliding indicator pill
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      left: selectedIndex * tabWidth,
                      top: 0,
                      bottom: 0,
                      width: tabWidth,
                      child: IgnorePointer(
                        child: Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: context.spacing.xxs,
                            vertical: context.spacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.textPrimary.withAlpha(28),
                            borderRadius: context.radius.asBorderRadiusCard,
                            border: Border.all(
                              color: context.colors.textPrimary.withAlpha(36),
                              width: context.sizes.borderThin,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Interactive tabs
                    Row(
                      children: List.generate(tabs.length, (index) {
                        final tab = tabs[index];
                        final isSelected = selectedIndex == index;

                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              if (tab.isEnabled) {
                                onTabSelected(index);
                              } else {
                                DilSeNotification.info(
                                  context,
                                  '${tab.label} is coming soon!',
                                  subtitle: 'We are crafting the ${tab.label.toLowerCase()} experience for you.',
                                );
                              }
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedScale(
                                  scale: isSelected ? 1.08 : 1.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    isSelected ? tab.activeIcon : tab.icon,
                                    color: isSelected
                                        ? context.colors.textPrimary
                                        : (tab.isEnabled
                                            ? context.colors.textSecondary
                                            : context.colors.textSecondary.withAlpha(120)),
                                    size: context.sizes.iconMd,
                                  ),
                                ),
                                SizedBox(height: context.spacing.xxs),
                                Text(
                                  tab.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.typography.captionMuted.copyWith(
                                    color: isSelected
                                        ? context.colors.textPrimary
                                        : (tab.isEnabled
                                            ? context.colors.textSecondary
                                            : context.colors.textSecondary.withAlpha(120)),
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isEnabled;

  const _NavTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isEnabled,
  });
}

