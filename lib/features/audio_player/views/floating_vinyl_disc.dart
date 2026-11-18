import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../data/models/song_model.dart';
import 'player_screen.dart';

/// Floating circular rotating vinyl CD player widget that appears when the user
/// scrolls down and the bottom navigation dock collapses.
///
/// Features:
/// - Realistic concentric vinyl micro-grooves and center circular album art.
/// - 33⅓ RPM continuous rotation synchronized with audio playback.
/// - Free horizontal/vertical dragging between bottom-left and bottom-right corners
///   with magnetic edge-snapping ergonomics.
/// - Tap gesture opens the full-size [PlayerScreen].
/// - Strictly conforms to AGENTS.md:
///   * Invariant 1: Zero singletons (pure widget presentation).
///   * Invariant 2: Context-Exposed Design Tokens (zero magic numbers).
///   * Invariant 3: Strict MVVM (View-only presentation).
///   * Invariant 4: B&W Monochrome theme (artwork is sole color exception).
class FloatingVinylDisc extends StatefulWidget {
  final bool isVisible;
  final SongModel song;
  final bool isPlaying;
  final VoidCallback? onTap;

  const FloatingVinylDisc({
    super.key,
    required this.isVisible,
    required this.song,
    required this.isPlaying,
    this.onTap,
  });

  @override
  State<FloatingVinylDisc> createState() => _FloatingVinylDiscState();
}

class _FloatingVinylDiscState extends State<FloatingVinylDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  // Drag position state
  bool _isDragging = false;
  double? _customX;
  double? _customY;
  double _dragDistance = 0.0;
  bool _isDockedLeft = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );

    if (widget.isPlaying && widget.isVisible) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant FloatingVinylDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying ||
        widget.isVisible != oldWidget.isVisible) {
      if (widget.isPlaying && widget.isVisible) {
        if (!_rotationController.isAnimating) {
          _rotationController.repeat();
        }
      } else {
        if (_rotationController.isAnimating) {
          _rotationController.stop();
        }
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _handleTap(BuildContext context) {
    HapticFeedback.selectionClick();
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const PlayerScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            final tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final discSize = context.sizes.floatingCdSize;
    final edgeMargin = context.spacing.md;
    final bottomMargin = context.spacing.lg;

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final safeBottom = mediaQuery.padding.bottom;

    // Default docked coordinates
    final defaultRightX = screenWidth - discSize - edgeMargin;
    final defaultLeftX = edgeMargin;
    final defaultY = screenHeight - discSize - bottomMargin - safeBottom;

    final targetX = _customX ?? (_isDockedLeft ? defaultLeftX : defaultRightX);
    final targetY = _customY ?? defaultY;

    return Positioned(
      left: targetX,
      top: targetY,
      child: IgnorePointer(
        ignoring: !widget.isVisible,
        child: AnimatedScale(
          scale: widget.isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: widget.isVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _handleTap(context),
              onPanStart: (details) {
                _isDragging = true;
                _dragDistance = 0.0;
              },
              onPanUpdate: (details) {
                _dragDistance += details.delta.distance;
                setState(() {
                  final curX =
                      _customX ??
                      (_isDockedLeft ? defaultLeftX : defaultRightX);
                  final curY = _customY ?? defaultY;

                  // Constrain inside screen bounds with edge margins
                  final newX = (curX + details.delta.dx).clamp(
                    edgeMargin,
                    screenWidth - discSize - edgeMargin,
                  );
                  final newY = (curY + details.delta.dy).clamp(
                    screenHeight * 0.4,
                    screenHeight - discSize - edgeMargin - safeBottom,
                  );

                  _customX = newX;
                  _customY = newY;
                });
              },
              onPanEnd: (details) {
                _isDragging = false;
                // If user barely moved finger, treat as tap
                if (_dragDistance < 6.0) {
                  _handleTap(context);
                  return;
                }

                HapticFeedback.selectionClick();

                // Snap magnetically to the closer horizontal edge (left or right)
                setState(() {
                  final currentCenterX =
                      (_customX ?? defaultRightX) + (discSize / 2);
                  final isLeft = currentCenterX < (screenWidth / 2);
                  _isDockedLeft = isLeft;

                  // Snap to safe docked coordinates
                  _customX = isLeft ? defaultLeftX : defaultRightX;
                  _customY = defaultY;
                });
              },
              child: AnimatedContainer(
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: discSize,
                height: discSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dynamic Ambient Aura Glow
                    Container(
                      width: discSize * 0.9,
                      height: discSize * 0.9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.oledBackground.withAlpha(200),
                            blurRadius: context.spacing.md,
                            spreadRadius: context.spacing.xxs,
                          ),
                          BoxShadow(
                            color: context.colors.solidMatteBorder.withAlpha(
                              120,
                            ),
                            blurRadius: context.spacing.sm,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),

                    // Rotating Vinyl Disc
                    RotationTransition(
                      turns: _rotationController,
                      child: Container(
                        width: discSize,
                        height: discSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.colors.cardDarkSurface,
                          border: Border.all(
                            color: context.colors.solidMatteBorder,
                            width: context.sizes.borderThin,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.oledBackground.withAlpha(
                                220,
                              ),
                              blurRadius: context.spacing.md,
                              offset: Offset(0, context.spacing.xs),
                            ),
                          ],
                        ),
                        child: CustomPaint(
                          painter: _MiniVinylGroovesPainter(
                            grooveColor: context.colors.solidMatteBorder
                                .withAlpha(90),
                            sheenColor: context.colors.textPrimary.withAlpha(
                              25,
                            ),
                          ),
                          child: Center(
                            child: _buildCenterLabel(context, discSize),
                          ),
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

  Widget _buildCenterLabel(BuildContext context, double discSize) {
    final labelSize = discSize * 0.44;
    final spindleSize = context.sizes.badgeDotSize * 0.6;

    return Container(
      width: labelSize,
      height: labelSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: context.colors.textPrimary,
          width: context.sizes.borderThin,
        ),
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.song.thumbnailUrl.isNotEmpty)
              Image.network(
                widget.song.thumbnailUrl,
                width: labelSize,
                height: labelSize,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: context.colors.cardDarkSurface,
                  child: Icon(
                    Icons.music_note,
                    color: context.colors.textSecondary,
                    size: context.sizes.iconSm,
                  ),
                ),
              )
            else
              Container(
                color: context.colors.cardDarkSurface,
                child: Icon(
                  Icons.music_note,
                  color: context.colors.textSecondary,
                  size: context.sizes.iconSm,
                ),
              ),

            // Center Spindle Hole
            Container(
              width: spindleSize,
              height: spindleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.oledBackground,
                border: Border.all(
                  color: context.colors.textSecondary,
                  width: context.sizes.borderThin,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter rendering concentric vinyl micro-grooves and optical reflection sheen.
class _MiniVinylGroovesPainter extends CustomPainter {
  final Color grooveColor;
  final Color sheenColor;

  _MiniVinylGroovesPainter({
    required this.grooveColor,
    required this.sheenColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final groovePaint = Paint()
      ..color = grooveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;

    // 3 concentric grooves
    canvas.drawCircle(center, radius * 0.88, groovePaint);
    canvas.drawCircle(center, radius * 0.74, groovePaint);
    canvas.drawCircle(center, radius * 0.60, groovePaint);

    // Subtle optical reflection sweep across the vinyl
    final sheenPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          sheenColor,
          Colors.transparent,
          sheenColor,
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        transform: const GradientRotation(math.pi / 4),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius - 1, sheenPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniVinylGroovesPainter oldDelegate) => false;
}
