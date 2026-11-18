import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/services/lyrics_transliteration_service.dart';

/// 3-Way Lyrics Display Architecture.
enum LyricsDisplayMode {
  /// Original script as provided (Telugu, Devanagari, Tamil, English, etc.)
  original,

  /// Phonetic Romanized English pronunciation (e.g. "Tenglish", "Hinglish")
  pronunciation,

  /// Dual stacked view showing original script on top with phonetic pronunciation below.
  dual,
}

class LyricLine {
  final Duration time;
  final String text;
  final String romanizedText;

  const LyricLine(this.time, this.text, [this.romanizedText = '']);
}

/// Dynamic animated lyrics view with 3-Way Architecture (Original | English Pronunciation | Dual),
/// real-time active line highlighting, auto-scroll, and interactive tap-to-seek playback.
class AnimatedLyrics extends StatefulWidget {
  final String rawLyrics;
  final String? pronunciationLyrics;
  final String? songTitle;
  final String? songArtist;
  final Stream<Duration> positionStream;
  final Duration initialPosition;
  final Color vibrantColor;
  final ValueChanged<Duration> onSeek;

  const AnimatedLyrics({
    super.key,
    required this.rawLyrics,
    this.pronunciationLyrics,
    this.songTitle,
    this.songArtist,
    required this.positionStream,
    required this.initialPosition,
    required this.vibrantColor,
    required this.onSeek,
  });

  @override
  State<AnimatedLyrics> createState() => _AnimatedLyricsState();
}

class _AnimatedLyricsState extends State<AnimatedLyrics> {
  static const String _prefKey = 'dilse_lyrics_display_mode';

  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  StreamSubscription<Duration>? _positionSubscription;

  List<LyricLine> _lyrics = [];
  bool _isSynced = false;
  bool _hasTransliteration = false;
  int _currentIndex = -1;
  LyricsDisplayMode _displayMode = LyricsDisplayMode.original;
  bool _isUserScrolling = false;
  Timer? _userScrollResumeTimer;

  @override
  void initState() {
    super.initState();
    _loadDisplayModePreference();
    _parseLyrics();
    _subscribeToPosition();
  }

  Future<void> _loadDisplayModePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && mounted) {
        setState(() {
          if (saved == 'pronunciation') {
            _displayMode = LyricsDisplayMode.pronunciation;
          } else if (saved == 'dual') {
            _displayMode = LyricsDisplayMode.dual;
          } else {
            _displayMode = LyricsDisplayMode.original;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveDisplayModePreference(LyricsDisplayMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = mode == LyricsDisplayMode.pronunciation
          ? 'pronunciation'
          : (mode == LyricsDisplayMode.dual ? 'dual' : 'original');
      await prefs.setString(_prefKey, modeStr);
    } catch (_) {}
  }

  void _subscribeToPosition() {
    _positionSubscription?.cancel();
    _positionSubscription = widget.positionStream.listen(_onPositionUpdate);
    _onPositionUpdate(widget.initialPosition);
  }

  void _onPositionUpdate(Duration position) {
    if (!mounted || !_isSynced || _lyrics.isEmpty) return;

    // Fast binary search for active lyric line
    int activeIndex = -1;
    int low = 0;
    int high = _lyrics.length - 1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (_lyrics[mid].time <= position) {
        activeIndex = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    if (activeIndex != _currentIndex) {
      setState(() {
        _currentIndex = activeIndex;
      });
      if (!_isUserScrolling) {
        _scrollToActiveLine(_currentIndex);
      }
    }
  }

  void _scrollToActiveLine(int index) {
    if (index < 0 || !_scrollController.hasClients) return;
    final key = _lineKeys[index];
    if (key == null || key.currentContext == null) {
      final targetOffset = (index * (context.sizes.playerHeroPlaySize * 0.8)) -
          context.sizes.miniPlayerHeight * 1.5;
      final clamped = targetOffset.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    Scrollable.ensureVisible(
      key.currentContext!,
      alignment: 0.35,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.positionStream != widget.positionStream) {
      _subscribeToPosition();
    }
    if (oldWidget.rawLyrics != widget.rawLyrics ||
        oldWidget.pronunciationLyrics != widget.pronunciationLyrics) {
      _parseLyrics();
    }
  }

  void _parseLyrics() {
    _lineKeys.clear();
    _currentIndex = -1;
    _hasTransliteration = false;

    if (widget.rawLyrics.trim().isEmpty) {
      _lyrics = [];
      _isSynced = false;
      return;
    }

    final lines = widget.rawLyrics.split('\n');
    final timeTagRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');
    final parsedSynced = <LyricLine>[];

    final bool hasNativeIndic = LyricsTransliterationService.hasIndicScript(widget.rawLyrics);
    final bool isRomanizedTelugu = LyricsTransliterationService.isRomanizedTelugu(widget.rawLyrics);

    if (hasNativeIndic || isRomanizedTelugu || widget.pronunciationLyrics != null) {
      _hasTransliteration = true;
    }

    for (final rawLine in lines) {
      final matches = timeTagRegex.allMatches(rawLine);
      if (matches.isNotEmpty) {
        final text = rawLine.replaceAll(timeTagRegex, '').trim();
        if (text.isEmpty) continue;

        final String originalText;
        final String pronunciationText;

        if (widget.pronunciationLyrics != null) {
          originalText = text;
          pronunciationText = widget.pronunciationLyrics!;
        } else if (isRomanizedTelugu) {
          pronunciationText = text;
          originalText = LyricsTransliterationService.toTeluguScript(text);
        } else if (hasNativeIndic) {
          originalText = text;
          pronunciationText = LyricsTransliterationService.transliterateText(text);
        } else {
          originalText = text;
          pronunciationText = text;
        }

        for (final m in matches) {
          final minutes = int.parse(m.group(1)!);
          final seconds = int.parse(m.group(2)!);
          int milliseconds = 0;
          final msGroup = m.group(3);
          if (msGroup != null) {
            if (msGroup.length == 1) {
              milliseconds = int.parse(msGroup) * 100;
            } else if (msGroup.length == 2) {
              milliseconds = int.parse(msGroup) * 10;
            } else {
              milliseconds = int.parse(msGroup.substring(0, 3));
            }
          }

          final duration = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          );
          parsedSynced.add(LyricLine(duration, originalText, pronunciationText));
        }
      }
    }

    if (parsedSynced.isNotEmpty) {
      _isSynced = true;
      parsedSynced.sort((a, b) => a.time.compareTo(b.time));
      _lyrics = parsedSynced;
    } else {
      // Unsynced Plain Text fallback
      _isSynced = false;
      final cleanRegex = RegExp(r'\[\s*(?:\d+\s*:\s*)?\d+\s*:\s*\d+(?:[.:]\d+)?\s*\]');
      final cleaned = <LyricLine>[];
      bool prevWasEmpty = false;

      for (final rawLine in lines) {
        final line = rawLine.replaceAll(cleanRegex, '').trim();
        if (RegExp(r'^\[[a-zA-Z]+:.*\]$').hasMatch(line)) continue;

        if (line.isEmpty) {
          if (!prevWasEmpty && cleaned.isNotEmpty) {
            cleaned.add(const LyricLine(Duration.zero, '', ''));
            prevWasEmpty = true;
          }
        } else {
          final String originalText;
          final String pronunciationText;

          if (isRomanizedTelugu) {
            pronunciationText = line;
            originalText = LyricsTransliterationService.toTeluguScript(line);
          } else if (hasNativeIndic) {
            originalText = line;
            pronunciationText = LyricsTransliterationService.transliterateText(line);
          } else {
            originalText = line;
            pronunciationText = line;
          }

          cleaned.add(LyricLine(Duration.zero, originalText, pronunciationText));
          prevWasEmpty = false;
        }
      }
      _lyrics = cleaned;
    }
  }

  void _onUserScrollStart() {
    _isUserScrolling = true;
    _userScrollResumeTimer?.cancel();
  }

  void _onUserScrollEnd() {
    _userScrollResumeTimer?.cancel();
    _userScrollResumeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _isUserScrolling = false;
        if (_isSynced && _currentIndex >= 0) {
          _scrollToActiveLine(_currentIndex);
        }
      }
    });
  }

  Widget _buildModeSelector(BuildContext context) {
    if (!_hasTransliteration) return const SizedBox.shrink();

    return Padding(
      padding: context.spacing.insetsVertical(context.spacing.xs),
      child: Center(
        child: Container(
          padding: context.spacing.insetsXxs,
          decoration: BoxDecoration(
            color: context.colors.cardDarkSurface.withValues(alpha: 0.85),
            borderRadius: context.radius.asBorderRadiusFull,
            border: Border.all(
              color: context.colors.solidMatteBorder,
              width: context.sizes.borderThin,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeButton(
                mode: LyricsDisplayMode.original,
                label: 'Original',
                icon: Icons.language_rounded,
              ),
              SizedBox(width: context.spacing.xxs),
              _buildModeButton(
                mode: LyricsDisplayMode.pronunciation,
                label: 'English',
                icon: Icons.spellcheck_rounded,
              ),
              SizedBox(width: context.spacing.xxs),
              _buildModeButton(
                mode: LyricsDisplayMode.dual,
                label: 'Dual',
                icon: Icons.view_agenda_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required LyricsDisplayMode mode,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _displayMode == mode;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _displayMode = mode;
        });
        _saveDisplayModePreference(mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: context.spacing.insetsSymmetric(
          horizontal: context.spacing.sm + context.spacing.xs,
          vertical: context.spacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected ? widget.vibrantColor : Colors.transparent,
          borderRadius: context.radius.asBorderRadiusFull,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: widget.vibrantColor.withValues(alpha: 0.45),
                    blurRadius: context.spacing.sm,
                    offset: Offset(0, context.spacing.xxs),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: context.sizes.iconSm * 0.85,
              color: isSelected
                  ? (widget.vibrantColor.computeLuminance() > 0.5
                      ? context.colors.oledBackground
                      : context.colors.textPrimary)
                  : context.colors.textSecondary,
            ),
            SizedBox(width: context.spacing.xs),
            Text(
              label,
              style: context.typography.eyebrow.copyWith(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (widget.vibrantColor.computeLuminance() > 0.5
                        ? context.colors.oledBackground
                        : context.colors.textPrimary)
                    : context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineContent(LyricLine item, bool isCurrent) {
    final hasRomanized = item.romanizedText.isNotEmpty && item.romanizedText != item.text;

    if (_displayMode == LyricsDisplayMode.dual && hasRomanized) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            item.text,
            textAlign: TextAlign.center,
            style: context.typography.headlineMedium.copyWith(
              color: isCurrent
                  ? context.colors.textPrimary
                  : context.colors.textPrimary.withValues(alpha: 0.38),
              fontSize: isCurrent ? 21.0 : 19.0,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              height: 1.35,
              shadows: isCurrent
                  ? [
                      Shadow(
                        color: widget.vibrantColor.withValues(alpha: 0.45),
                        blurRadius: context.spacing.md,
                      ),
                    ]
                  : null,
            ),
          ),
          SizedBox(height: context.spacing.xs),
          Text(
            item.romanizedText,
            textAlign: TextAlign.center,
            style: context.typography.bodyLarge.copyWith(
              color: isCurrent
                  ? context.colors.textPrimary.withValues(alpha: 0.90)
                  : context.colors.textSecondary.withValues(alpha: 0.35),
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.2,
            ),
          ),
        ],
      );
    }

    final displayText = (_displayMode == LyricsDisplayMode.pronunciation && hasRomanized)
        ? item.romanizedText
        : item.text;

    return Text(
      displayText,
      textAlign: TextAlign.center,
      style: context.typography.headlineMedium.copyWith(
        color: isCurrent
            ? context.colors.textPrimary
            : context.colors.textPrimary.withValues(alpha: 0.38),
        fontSize: isCurrent ? 22.0 : 20.0,
        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
        height: 1.4,
        shadows: isCurrent
            ? [
                Shadow(
                  color: widget.vibrantColor.withValues(alpha: 0.45),
                  blurRadius: context.spacing.md,
                ),
              ]
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_lyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: context.sizes.avatarLg,
              color: context.colors.textSecondary.withValues(alpha: 0.5),
            ),
            SizedBox(height: context.spacing.md),
            Text(
              'No lyrics found for this track',
              style: context.typography.titleMedium.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            SizedBox(height: context.spacing.xs),
            Text(
              'Enjoy the pure acoustic rhythm',
              style: context.typography.bodyMedium.copyWith(
                color: context.colors.textSecondary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildModeSelector(context),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                _onUserScrollStart();
              } else if (notification is ScrollEndNotification) {
                _onUserScrollEnd();
              }
              return false;
            },
            child: ListView.builder(
              controller: _scrollController,
              padding: context.spacing.insetsSymmetric(
                horizontal: context.spacing.lg,
                vertical: context.spacing.xxl,
              ),
              physics: const BouncingScrollPhysics(),
              itemCount: _lyrics.length,
              itemBuilder: (context, index) {
                final item = _lyrics[index];
                final isCurrent = _isSynced && index == _currentIndex;
                final key = _lineKeys.putIfAbsent(index, () => GlobalKey());

                if (item.text.isEmpty && item.romanizedText.isEmpty) {
                  return SizedBox(height: context.spacing.lg);
                }

                return GestureDetector(
                  key: key,
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_isSynced) {
                      HapticFeedback.lightImpact();
                      widget.onSeek(item.time);
                    }
                  },
                  child: Padding(
                    padding: context.spacing.insetsVertical(
                      _displayMode == LyricsDisplayMode.dual ? context.spacing.md : context.spacing.sm,
                    ),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: isCurrent ? 1.0 : (_isSynced ? 0.38 : 0.85),
                      child: _buildLineContent(item, isCurrent),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _userScrollResumeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}
