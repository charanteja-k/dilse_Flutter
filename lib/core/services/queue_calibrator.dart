import '../../data/models/song_model.dart';

/// The four distinct algorithmic calibration modes for DilSe's 50-track queue.
enum QueueMode {
  /// 60% Discovery / 40% Familiar with cross-language bridges (Default).
  blend,

  /// 70% Discovery / 30% Familiar (Exploration-first).
  discover,

  /// 40% Discovery / 60% Familiar (Comfort / favorites-first).
  familiar,

  /// 100% strict single-language quarantine.
  singleLanguage,
}

/// Metadata tag indicating why a track was recommended in the queue.
enum QueueTrackBadge {
  topArtist,
  inLibrary,
  discovery,
  similarVibe,
}

/// Pure Dart queue calibration engine.
/// Calibrates candidate radio tracks against user listening history and selected mode.
/// Zero singletons, zero UI dependencies.
class QueueCalibrator {
  const QueueCalibrator();

  /// Returns calibrated upcoming tracks with appropriate pacing and metadata tags.
  List<({SongModel song, QueueTrackBadge badge})> calibrate({
    required SongModel seedSong,
    required List<SongModel> rawCandidates,
    required QueueMode mode,
    List<SongModel> userLikedSongs = const [],
    List<SongModel> userHistory = const [],
  }) {
    if (rawCandidates.isEmpty) return const [];

    // 1. Build user artist frequency profile
    final artistAffinities = <String, int>{};
    final likedSongTitles = <String>{};

    for (final s in userLikedSongs) {
      final cleanTitle = s.title.toLowerCase().trim();
      if (cleanTitle.isNotEmpty) likedSongTitles.add(cleanTitle);
      _tallyArtists(s.artist, artistAffinities);
    }
    for (final s in userHistory) {
      _tallyArtists(s.artist, artistAffinities);
    }

    // 2. Classify raw candidate tracks
    final seenTitles = <String>{seedSong.title.toLowerCase().trim()};
    final classified = <({
      SongModel song,
      bool isKnown,
      QueueTrackBadge badge,
      bool isSameLanguage,
    })>[];

    final seedLang = _inferLanguage(seedSong);

    for (final candidate in rawCandidates) {
      final titleKey = candidate.title.toLowerCase().trim();
      if (seenTitles.contains(titleKey) || candidate.id == seedSong.id) {
        continue;
      }
      seenTitles.add(titleKey);

      final isLiked = likedSongTitles.contains(titleKey);
      final hasTopArtist = _hasTopArtistMatch(candidate.artist, artistAffinities);
      final isKnown = isLiked || hasTopArtist;

      final isSameLang = _isLanguageMatch(candidate, seedLang);

      QueueTrackBadge badge;
      if (hasTopArtist) {
        badge = QueueTrackBadge.topArtist;
      } else if (isLiked) {
        badge = QueueTrackBadge.inLibrary;
      } else if (isSameLang) {
        badge = QueueTrackBadge.discovery;
      } else {
        badge = QueueTrackBadge.similarVibe;
      }

      classified.add((
        song: candidate,
        isKnown: isKnown,
        badge: badge,
        isSameLanguage: isSameLang,
      ));
    }

    // 3. Filter candidates based on mode
    List<({SongModel song, bool isKnown, QueueTrackBadge badge})> eligible;
    if (mode == QueueMode.singleLanguage) {
      // In single language mode, strictly quarantine to same language
      final filtered = classified.where((c) => c.isSameLanguage).toList();
      eligible = (filtered.isNotEmpty ? filtered : classified)
          .map((c) => (song: c.song, isKnown: c.isKnown, badge: c.badge))
          .toList();
    } else {
      eligible = classified
          .map((c) => (song: c.song, isKnown: c.isKnown, badge: c.badge))
          .toList();
    }

    final knownPool = eligible.where((c) => c.isKnown).toList();
    final unknownPool = eligible.where((c) => !c.isKnown).toList();

    // 4. Interleave according to the selected mode's target rhythm
    final int stepUnknown;
    final int stepKnown;

    switch (mode) {
      case QueueMode.blend:
        // 60/40 ratio: 3 unknown, 2 known
        stepUnknown = 3;
        stepKnown = 2;
        break;
      case QueueMode.discover:
        // 70/30 ratio: 7 unknown, 3 known
        stepUnknown = 7;
        stepKnown = 3;
        break;
      case QueueMode.familiar:
        // 40/60 ratio: 2 unknown, 3 known
        stepUnknown = 2;
        stepKnown = 3;
        break;
      case QueueMode.singleLanguage:
        // Balanced single-language pacing: 3 unknown, 2 known
        stepUnknown = 3;
        stepKnown = 2;
        break;
    }

    final result = <({SongModel song, QueueTrackBadge badge})>[];
    int kIdx = 0;
    int uIdx = 0;

    while (result.length < eligible.length) {
      // Add unknown batch
      for (int i = 0; i < stepUnknown; i++) {
        if (uIdx < unknownPool.length) {
          result.add((song: unknownPool[uIdx].song, badge: unknownPool[uIdx].badge));
          uIdx++;
        } else if (kIdx < knownPool.length) {
          result.add((song: knownPool[kIdx].song, badge: knownPool[kIdx].badge));
          kIdx++;
        }
      }

      // Add known batch
      for (int i = 0; i < stepKnown; i++) {
        if (kIdx < knownPool.length) {
          result.add((song: knownPool[kIdx].song, badge: knownPool[kIdx].badge));
          kIdx++;
        } else if (uIdx < unknownPool.length) {
          result.add((song: unknownPool[uIdx].song, badge: unknownPool[uIdx].badge));
          uIdx++;
        }
      }

      // Safeguard against infinite loops
      if (kIdx >= knownPool.length && uIdx >= unknownPool.length) {
        break;
      }
    }

    return result;
  }

  void _tallyArtists(String artistStr, Map<String, int> targetMap) {
    if (artistStr.isEmpty) return;
    final parts = artistStr.split(RegExp(r'[,;/|&]'));
    for (final p in parts) {
      final clean = p.trim().toLowerCase();
      if (clean.isNotEmpty) {
        targetMap[clean] = (targetMap[clean] ?? 0) + 1;
      }
    }
  }

  bool _hasTopArtistMatch(String candidateArtist, Map<String, int> artistAffinities) {
    if (candidateArtist.isEmpty || artistAffinities.isEmpty) return false;
    final parts = candidateArtist.split(RegExp(r'[,;/|&]'));
    for (final p in parts) {
      final clean = p.trim().toLowerCase();
      if (clean.isNotEmpty && (artistAffinities[clean] ?? 0) >= 2) {
        return true;
      }
    }
    return false;
  }

  String _inferLanguage(SongModel song) {
    final combined = '${song.title} ${song.artist} ${song.album}'.toLowerCase();
    if (combined.contains('telugu') || combined.contains('devara') || combined.contains('rrr')) {
      return 'telugu';
    }
    if (combined.contains('hindi') || combined.contains('bollywood') || combined.contains('aashiqui')) {
      return 'hindi';
    }
    if (combined.contains('tamil') || combined.contains('kollywood')) {
      return 'tamil';
    }
    return 'unknown';
  }

  bool _isLanguageMatch(SongModel candidate, String seedLang) {
    if (seedLang == 'unknown') return true;
    final combined = '${candidate.title} ${candidate.artist} ${candidate.album}'.toLowerCase();
    if (seedLang == 'telugu') {
      // Discard distinct Hindi/Punjabi keywords if in single language mode
      if (combined.contains('chaleya') ||
          combined.contains('chammak challo') ||
          combined.contains('dhurandhar') ||
          combined.contains('punjabi')) {
        return false;
      }
    }
    return true;
  }
}
