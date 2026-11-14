import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../extensions/context_extensions.dart';

enum DilSeNotificationType { success, info, warning, error, heart, download }

/// Modern Dynamic Island / Floating HUD in-app notification system for DilSe.
///
/// Replaces clunky generic rectangular bottom snackbars with a sleek, floating HUD pill
/// positioned at the top of the viewport. Features smooth spring-down entrance physics,
/// glowing status badges, tap-to-dismiss, and swipe-up gestures.
///
/// Adheres strictly to AGENTS.md:
/// - Invariant 1: Pure stateless/stateful overlay, zero singletons.
/// - Invariant 2: Context design tokens only (spacing, radius, typography, colors, sizes).
class DilSeNotification {
  DilSeNotification._();

  static OverlayEntry? _activeEntry;

  /// Shows a floating notification pill.
  static void show(
    BuildContext context, {
    required String message,
    String? subtitle,
    DilSeNotificationType type = DilSeNotificationType.info,
    IconData? customIcon,
    Duration duration = const Duration(milliseconds: 2400),
    VoidCallback? onTap,
  }) {
    dismiss();

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    HapticFeedback.lightImpact();

    _activeEntry = OverlayEntry(
      builder: (ctx) => _DilSeNotificationPill(
        message: message,
        subtitle: subtitle,
        type: type,
        customIcon: customIcon,
        duration: duration,
        onTap: onTap,
        onDismiss: dismiss,
      ),
    );

    overlay.insert(_activeEntry!);
  }

  /// Convenience helper for success messages.
  static void success(
    BuildContext context,
    String message, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      type: DilSeNotificationType.success,
      onTap: onTap,
    );
  }

  /// Convenience helper for informational updates.
  static void info(
    BuildContext context,
    String message, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      type: DilSeNotificationType.info,
      onTap: onTap,
    );
  }

  /// Convenience helper for warnings.
  static void warning(
    BuildContext context,
    String message, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      type: DilSeNotificationType.warning,
      onTap: onTap,
    );
  }

  /// Convenience helper for error messages.
  static void error(
    BuildContext context,
    String message, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      type: DilSeNotificationType.error,
      onTap: onTap,
    );
  }

  /// Convenience helper for favoriting / hearting songs.
  static void heart(
    BuildContext context,
    String message, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      type: DilSeNotificationType.heart,
      onTap: onTap,
    );
  }

  /// Convenience helper for downloads.
  static void download(
    BuildContext context,
    String message, {
    String? subtitle,
    bool isSuccess = true,
    VoidCallback? onTap,
  }) {
    show(
      context,
      message: message,
      subtitle: subtitle,
      type: isSuccess
          ? DilSeNotificationType.download
          : DilSeNotificationType.warning,
      onTap: onTap,
    );
  }

  /// Dismisses active notification entry immediately.
  static void dismiss() {
    if (_activeEntry != null) {
      _activeEntry?.remove();
      _activeEntry = null;
    }
  }
}

class _DilSeNotificationPill extends StatefulWidget {
  final String message;
  final String? subtitle;
  final DilSeNotificationType type;
  final IconData? customIcon;
  final Duration duration;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const _DilSeNotificationPill({
    required this.message,
    this.subtitle,
    required this.type,
    this.customIcon,
    required this.duration,
    this.onTap,
    required this.onDismiss,
  });

  @override
  State<_DilSeNotificationPill> createState() => _DilSeNotificationPillState();
}

class _DilSeNotificationPillState extends State<_DilSeNotificationPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleXAnimation;
  late final Animation<double> _scaleYAnimation;

  @override
  void initState() {
    super.initState();

    final enterMs = 320.0;
    final holdMs = widget.duration.inMilliseconds.toDouble();
    final exitMs = 220.0;
    final totalDuration = Duration(
      milliseconds: (enterMs + holdMs + exitMs).toInt(),
    );

    _controller = AnimationController(vsync: this, duration: totalDuration);

    _slideAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: enterMs,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: holdMs),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: -1.2,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: exitMs,
      ),
    ]).animate(_controller);

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: enterMs,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: holdMs),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: exitMs,
      ),
    ]).animate(_controller);

    _scaleXAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.38,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: enterMs,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: holdMs),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.85,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: exitMs,
      ),
    ]).animate(_controller);

    _scaleYAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.65,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: enterMs,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: holdMs),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.85,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: exitMs,
      ),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismiss();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    _controller.stop();
    widget.onDismiss();
  }

  Color _resolveAccentColor(BuildContext context) {
    switch (widget.type) {
      case DilSeNotificationType.success:
      case DilSeNotificationType.download:
        return context.colors.successEmerald;
      case DilSeNotificationType.heart:
        return context.colors.brandRuby;
      case DilSeNotificationType.warning:
        return context.colors.warningAmber;
      case DilSeNotificationType.error:
        return context.colors.errorCrimson;
      case DilSeNotificationType.info:
        return context.colors.textSecondary;
    }
  }

  IconData get _icon {
    if (widget.customIcon != null) return widget.customIcon!;
    switch (widget.type) {
      case DilSeNotificationType.success:
        return Icons.check_circle_rounded;
      case DilSeNotificationType.download:
        return Icons.download_done_rounded;
      case DilSeNotificationType.heart:
        return Icons.favorite_rounded;
      case DilSeNotificationType.warning:
        return Icons.info_outline_rounded;
      case DilSeNotificationType.error:
        return Icons.error_outline_rounded;
      case DilSeNotificationType.info:
        return Icons.music_note_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top > 0
        ? mediaQuery.padding.top + context.spacing.sm
        : context.spacing.lg;
    final accentColor = _resolveAccentColor(context);

    return Positioned(
      top: topPadding,
      left: context.spacing.md,
      right: context.spacing.md,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value * context.sizes.navDockHeight),
              child: Transform.scale(
                scaleX: _scaleXAnimation.value,
                scaleY: _scaleYAnimation.value,
                alignment: Alignment.topCenter,
                child: Opacity(
                  opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                  child: child,
                ),
              ),
            );
          },
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta != null && details.primaryDelta! < -4) {
                _handleDismiss();
              }
            },
            onTap: () {
              if (widget.onTap != null) {
                widget.onTap!();
              }
              _handleDismiss();
            },
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                constraints: BoxConstraints(maxWidth: context.sizes.heroCardWidth + context.sizes.heroCardHeight),
                padding: context.spacing.insetsSymmetric(
                  horizontal: context.spacing.md,
                  vertical: context.spacing.sm + context.spacing.xxs,
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
                      color: context.colors.oledBackground.withValues(alpha: 0.70),
                      blurRadius: context.spacing.lg,
                      offset: Offset(0, context.spacing.sm),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: context.spacing.insetsXs + context.spacing.insetsXxs,
                      decoration: BoxDecoration(
                        color: context.colors.cardDarkSurface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _icon,
                        color: accentColor,
                        size: context.sizes.iconSm,
                      ),
                    ),
                    SizedBox(width: context.spacing.sm + context.spacing.xs),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.message,
                            style: context.typography.titleMedium.copyWith(
                              letterSpacing: -0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                            SizedBox(height: context.spacing.xxs),
                            Text(
                              widget.subtitle!,
                              style: context.typography.captionMuted,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: context.spacing.sm),
                    GestureDetector(
                      onTap: _handleDismiss,
                      child: Padding(
                        padding: context.spacing.insetsXs,
                        child: Icon(
                          Icons.close_rounded,
                          size: context.sizes.iconSm * 0.9,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

