import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/extensions/context_extensions.dart';

class LyricLine {
  final Duration time;
  final String text;

  const LyricLine(this.time, this.text);
}

/// Dynamic animated lyrics view with real-time active line highlighting, auto-scroll,
/// and interactive tap-to-seek playback.
class AnimatedLyrics extends StatefulWidget {
  final String rawLyrics;
  final String? songTitle;
  final String? songArtist;
  final Stream<Duration> positionStream;
  final Duration initialPosition;
  final Color vibrantColor;
  final ValueChanged<Duration> onSeek;

  const AnimatedLyrics({
    super.key,
    required this.rawLyrics,
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
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  StreamSubscription<Duration>? _positionSubscription;

  List<LyricLine> _lyrics = [];
  bool _isSynced = false;
  int _currentIndex = -1;
  bool _isUserScrolling = false;
  Timer? _userScrollResumeTimer;

  @override
  void initState() {
    super.initState();
    _parseLyrics();
    _subscribeToPosition();
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
      // Estimate approximate offset based on average line height
      const estimatedLineHeight = 56.0;
      final targetOffset = (index * estimatedLineHeight) - 140.0;
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
    if (oldWidget.rawLyrics != widget.rawLyrics) {
      _lineKeys.clear();
      setState(() {
        _currentIndex = -1;
        _parseLyrics();
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _userScrollResumeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _parseLyrics() {
    _lyrics.clear();
    _lineKeys.clear();
    _isSynced = false;
    _currentIndex = -1;

    final trimmed = widget.rawLyrics.trim();
    if (trimmed.isEmpty) return;

    final lines = trimmed.split('\n');
    // Regex matching LRC tags: [01:23.45], [00:01:23.45], [1:23.456]
    final tagRegex = RegExp(
      r'\[\s*(?:(\d{1,2})\s*:\s*)?(\d{1,2})\s*:\s*(\d{2})(?:[.:](\d{1,4}))?\s*\]',
    );

    final parsedSynced = <LyricLine>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Ignore LRC header tags
      if (RegExp(r'^\[\s*[a-zA-Z]+:.*\]$').hasMatch(line)) continue;

      final matches = tagRegex.allMatches(line);
      if (matches.isNotEmpty) {
        final text = line.replaceAll(tagRegex, '').trim();
        final displayText = text.isEmpty ? '♪  ♪  ♪' : text;

        for (final m in matches) {
          final hoursGroup = m.group(1);
          final hours = hoursGroup != null ? int.parse(hoursGroup) : 0;
          final minutes = int.parse(m.group(2)!);
          final seconds = int.parse(m.group(3)!);
          int milliseconds = 0;
          final msGroup = m.group(4);
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
            hours: hours,
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          );
          parsedSynced.add(LyricLine(duration, displayText));
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
      final cleaned = <LyricLine>[];
      for (final raw in lines) {
        final text = raw.trim();
        if (text.isNotEmpty) {
          cleaned.add(LyricLine(Duration.zero, text));
        }
      }
      _lyrics = cleaned;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note_rounded,
              color: context.colors.textSecondary,
              size: context.sizes.iconLg,
            ),
            SizedBox(height: context.spacing.sm),
            Text(
              'No lyrics found for this track',
              style: context.typography.bodyLarge.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _isUserScrolling = true;
          _userScrollResumeTimer?.cancel();
        } else if (notification is ScrollEndNotification) {
          _userScrollResumeTimer?.cancel();
          _userScrollResumeTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) {
              setState(() {
                _isUserScrolling = false;
              });
              if (_isSynced && _currentIndex >= 0) {
                _scrollToActiveLine(_currentIndex);
              }
            }
          });
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.md,
          vertical: context.spacing.lg,
        ),
        itemCount: _lyrics.length,
        itemBuilder: (context, index) {
          final line = _lyrics[index];
          final isCurrent = _isSynced && index == _currentIndex;
          final key = _lineKeys.putIfAbsent(index, () => GlobalKey());

          return GestureDetector(
            key: key,
            behavior: HitTestBehavior.opaque,
            onTap: _isSynced
                ? () {
                    HapticFeedback.lightImpact();
                    widget.onSeek(line.time);
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                vertical: isCurrent ? context.spacing.sm : context.spacing.xs,
                horizontal: context.spacing.xs,
              ),
              child: Text(
                line.text,
                style: isCurrent
                    ? context.typography.titleLarge.copyWith(
                        color: widget.vibrantColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 20.0,
                        shadows: [
                          Shadow(
                            color: widget.vibrantColor.withAlpha(128),
                            blurRadius: 16.0,
                          ),
                        ],
                      )
                    : context.typography.bodyLarge.copyWith(
                        color: context.colors.textPrimary.withAlpha(
                          _isSynced ? 110 : 200,
                        ),
                        fontWeight: FontWeight.w500,
                        fontSize: 16.0,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

