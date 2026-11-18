import 'package:flutter/material.dart';
import '../../../core/extensions/context_extensions.dart';

/// Rotating Vinyl Record Player with realistic physical grooves and ambient optical sheen.
/// Pure presentation widget following AGENTS.md Invariant 2 (tokenized context delivery).
class VinylRecordPlayer extends StatefulWidget {
  final String imageUrl;
  final bool isPlaying;
  final Color dominantColor;
  final Color vibrantColor;
  final double size;

  const VinylRecordPlayer({
    super.key,
    required this.imageUrl,
    required this.isPlaying,
    required this.dominantColor,
    required this.vibrantColor,
    this.size = 280,
  });

  @override
  State<VinylRecordPlayer> createState() => _VinylRecordPlayerState();
}

class _VinylRecordPlayerState extends State<VinylRecordPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );

    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant VinylRecordPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discSize = widget.size;
    final labelSize = discSize * 0.42;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Dynamic Ambient Aura Glow Behind the Vinyl
          AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            width: discSize * 0.95,
            height: discSize * 0.95,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.vibrantColor.withAlpha(115),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
                BoxShadow(
                  color: widget.dominantColor.withAlpha(140),
                  blurRadius: 65,
                  spreadRadius: 18,
                ),
              ],
            ),
          ),

          // 2. The Rotating Vinyl Disc
          RotationTransition(
            turns: _rotationController,
            child: Container(
              width: discSize,
              height: discSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFF16161A),
                    Color(0xFF0D0D10),
                    Color(0xFF1A1A1A),
                    Color(0xFF09090C),
                    Color(0xFF141418),
                    Color(0xFF050507),
                  ],
                  stops: [0.0, 0.35, 0.5, 0.72, 0.9, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.oledBackground.withAlpha(200),
                    blurRadius: 28,
                    spreadRadius: 4,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Realistic Vinyl Grooves & Optical Light Sheen
                  Positioned.fill(
                    child: CustomPaint(painter: _VinylGroovesPainter()),
                  ),

                  // Center Label (Song Album Artwork)
                  ClipOval(
                    child: SizedBox(
                      width: labelSize,
                      height: labelSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          widget.imageUrl.isNotEmpty
                              ? Image.network(
                                  widget.imageUrl,
                                  fit: BoxFit.cover,
                                  width: labelSize,
                                  height: labelSize,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: context.colors.cardDarkSurface,
                                        child: Icon(
                                          Icons.music_note_rounded,
                                          color: context.colors.textSecondary,
                                          size: context.sizes.iconLg,
                                        ),
                                      ),
                                )
                              : Container(
                                  color: context.colors.cardDarkSurface,
                                  child: Icon(
                                    Icons.music_note_rounded,
                                    color: context.colors.textSecondary,
                                    size: context.sizes.iconLg,
                                  ),
                                ),
                          // Subtle dark rim around artwork label
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.colors.oledBackground.withAlpha(
                                  128,
                                ),
                                width: 2,
                              ),
                            ),
                          ),
                          // Center Spindle Hole
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF0E0E12),
                              border: Border.all(
                                color: const Color(0xFFC0C0C0),
                                width: 2.2,
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black54, blurRadius: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter rendering realistic micro-grooves and dual optical sheen across the vinyl disc.
class _VinylGroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final groovePaint = Paint()
      ..color = Colors.white.withAlpha(12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    // Concentric vinyl groove tracks
    const int numGrooves = 18;
    final double startRadius = radius * 0.44;
    final double step = (radius * 0.92 - startRadius) / numGrooves;

    for (int i = 0; i < numGrooves; i++) {
      canvas.drawCircle(center, startRadius + (i * step), groovePaint);
    }

    // Realistic optical light sheen (dual reflection wedges typical on rotating lacquer)
    final sheenPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.white.withAlpha(18),
          Colors.transparent,
          Colors.transparent,
          Colors.white.withAlpha(18),
          Colors.transparent,
        ],
        stops: const [0.0, 0.22, 0.45, 0.5, 0.72, 0.95],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sheenPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
