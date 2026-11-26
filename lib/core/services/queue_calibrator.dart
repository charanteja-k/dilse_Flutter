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

  static const _teluguKeywords = [
    'telugu', 'tollywood', 'aditya music', 'mango music', 'lahari', 'chuttamalle', 'devara',
    'rrr', 'saranga dariya', 'samajavaragamana', 'buttabomma', 'inkem inkem', 'kurchi madathapetti',
    'srivalli', 'pushpa', 'geetha govindam', 'ala vaikunthapurramuloo', 'guntur kaaram', 'hanuman',
    'salaar', 'kalki', 'nuvvu', 'nenu', 'neetho', 'naatho', 'prema', 'kanulu', 'choodu', 'raave',
    'pilla', 'gundello', 'chesina', 'manushulu', 'chesave', 'unnodu', 'evaru', 'andala', 'oka',
    'rendu', 'tandri', 'venkata', 'ramana', 'shiva', 'yettaagayya', 'varsham', 'munduga', 'priya',
    'urime', 'manase', 'neneppudaina', 'dhinaku', 'dhin', 'jiya', 'dookudu', 'murari', 'ragava',
    'rama', 'dethadi', 'kannullo', 'choosi', 'choodangane', 'mellaga', 'adiga', 'adigaa',
    'sega', 'geetanjali', 'aatagadhara siva',
  ];

  static const _hindiKeywords = [
    'hindi', 'bollywood', 't-series', 'zee music', 'yrf', 'kesariya', 'tum hi ho', 'channa mereya',
    'apna bana le', 'aashiqui', 'sunn raha hai', 'tera', 'meri', 'hum', 'hamara', 'dil', 'pyaar',
    'ishq', 'mohabbat', 'zindagi', 'saathiya', 'kahani', 'khuda', 'dua', 'raat', 'aankhon',
    'deewana', 'dhadkan', 'sanam', 'o rangrez', 'bhaag milkha', 'azeem-o-shaan', 'jodhaa akbar',
    'ganpati aarti', 'sarkar 3', 'kalank', 'kabira', 'agar tum', 'tujh mein rab', 'chaleya',
    'chammak challo', 'dhurandhar', 'raataan lambiyan', 'shayad', 'pal', 'jeena jeena',
  ];

  static const _tamilKeywords = [
    'tamil', 'kollywood', 'rowdy baby', 'vaathi coming', 'arabic kuthu', 'enjoy enjaami',
    'kutty pattas', 'master the blaster', 'chellamma', 'two two two', 'naan pizhai', 'bae',
    'maari', 'master', 'beast', 'doctor', 'kaathuvaakula', 'jailer', 'leo', 'vikram', 'ponniyin',
    'selvan', 'kaadhal', 'kadhal', 'anbe', 'kannazhaga',
  ];

  static const _punjabiKeywords = [
    'punjabi', 'brown munde', 'insane', 'excuses', 'spaceship', 'majhaail', 'desires', 'tere te',
    'g.o.a.t', 'born to shine', 'clash', 'lehanga', 'naah', 'prada', 'lahore', 'high rated gabru',
  ];

  static const _teluguComposers = {
    'devi sri prasad', 'dsp', 'thaman', 'thaman s', 's. thaman', 'm.m. keeravaani', 'm. m. keeravani',
    'keeravani', 'keeravaani', 'mani sharma', 'mickey j meyer', 'mickey j. meyer', 'vivek sagar',
    'bheems ceciroleo', 'bheems', 'chaitan bharadwaj', 'anup rubens', 'koti', 'chakri',
    'r.p. patnaik', 'rp patnaik', 'mahati swara sagar', 'radhan',
  };

  static const _hindiComposers = {
    'pritam', 'vishal-shekhar', 'sachin-jigar', 'shankar-ehsaan-loy', 'mithoon',
    'amit trivedi', 'tanishk bagchi', 'rochak kohli', 'salim-sulaiman', 'himesh reshammiya',
    'jatin-lalit', 'nadeem-shravan', 'anu malik', 'laxmikant-pyarelal', 'r.d. burman', 'rd burman',
    'b praak', 'jaani', 'badshah', 'yo yo honey singh', 'honey singh', 'raftaar',
  };

  static const _tamilComposers = {
    'ilaiyaraaja', 'ilayaraja', 'harris jayaraj', 'yuvan shankar raja', 'd. imman', 'd imman',
    'g.v. prakash kumar', 'g. v. prakash', 'sean roldan', 'sam c.s.', 'hiphop tamizha', 'vidyasagar',
  };

  static const _teluguSingers = {
    's. p. balasubrahmanyam', 's.p. balasubrahmanyam', 'spb', 's.p. balu', 'balasubrahmanyam',
    'anurag kulkarni', 'ram miriyala', 'mangli', 'geetha madhuri', 'sunitha', 'rahul sipligunj',
    'penchal das', 'lipsika', 'srikrishna', 'sri krishna', 'dhanunjay', 'hemachandra',
    'kaala bhairava', 'kala bhairava', 'mohana bhogaraju', 'deepu', 'revanth', 'malavika',
    'karunya', 'bhaskarabhatla', 'chandrabose', 'sirivennela', 'srimani', 'veturi',
    'ramajogayya sastry', 'ananta sriram', 'kasarla shyam', 'jonnavithula',
  };

  static const _hindiSingers = {
    'arijit singh', 'sonu nigam', 'atif aslam', 'mohit chauhan', 'jubin nautiyal',
    'kumar sanu', 'udit narayan', 'alka yagnik', 'sunidhi chauhan', 'javed ali', 'kk',
    'rahat fateh ali khan', 'lucky ali', 'darshan raval', 'vishal mishra',
    'neha kakkar', 'tony kakkar', 'tulsi kumar', 'monali thakur', 'mika singh',
    'sachet tandon', 'parampara tandon', 'stebin ben',
  };

  static const _tamilSingers = {
    'dhanush', 'dhee', 'andrea jeremiah', 'shakthisree gopalan', 'naresh iyer',
  };

  static const _punjabiSingers = {
    'ap dhillon', 'gurinder gill', 'shubh', 'sidhu moose wala', 'diljit dosanjh', 'karan aujla',
    'amrit maan', 'harrdy sandhu', 'jassi gill', 'guru randhawa', 'sukhe', 'mankirt aulakh',
  };

  static const _englishArtists = {
    'the weeknd', 'taylor swift', 'ed sheeran', 'drake', 'post malone', 'bruno mars',
    'billie eilish', 'coldplay', 'imagine dragons', 'dua lipa', 'justin bieber', 'ariana grande',
    'eminem', 'rihanna', 'katy perry', 'maroon 5', 'adele', 'sam smith', 'shawn mendes',
    'the chainsmokers', 'chainsmokers', 'hans zimmer', 'alan walker', 'sia', 'charlie puth',
    'selena gomez', 'kendrick lamar', 'akon', 'enya', 'the wellermen', 'sickick', 'duncan laurence',
    'bebe rexha', 'david guetta', 'marshmello', 'avicii', 'calvin harris', 'travis scott',
    'kanye west', 'twenty one pilots', 'one direction', 'harry styles', 'zayn', 'lady gaga',
  };

  String _inferLanguage(SongModel song) {
    final text = '${song.title} ${song.artist} ${song.album}'.toLowerCase();

    // 1. Unicode script match
    if (RegExp(r'[\u0C00-\u0C7F]').hasMatch(text)) return 'telugu';
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) return 'hindi';
    if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(text)) return 'tamil';
    if (RegExp(r'[\u0A00-\u0A7F]').hasMatch(text)) return 'punjabi';
    if (RegExp(r'[\u0D00-\u0D7F]').hasMatch(text)) return 'malayalam';
    if (RegExp(r'[\u0C80-\u0CFF]').hasMatch(text)) return 'kannada';

    // 2. Strong Title / Album Keywords
    for (final kw in _teluguKeywords) {
      if (text.contains(kw)) return 'telugu';
    }
    for (final kw in _hindiKeywords) {
      if (text.contains(kw)) return 'hindi';
    }
    for (final kw in _tamilKeywords) {
      if (text.contains(kw)) return 'tamil';
    }
    for (final kw in _punjabiKeywords) {
      if (text.contains(kw)) return 'punjabi';
    }

    // 3. Core Composers
    for (final c in _teluguComposers) {
      if (text.contains(c)) return 'telugu';
    }
    for (final c in _hindiComposers) {
      if (text.contains(c)) return 'hindi';
    }
    for (final c in _tamilComposers) {
      if (text.contains(c)) return 'tamil';
    }

    // 4. Regional Singers
    for (final s in _teluguSingers) {
      if (text.contains(s)) return 'telugu';
    }
    for (final s in _hindiSingers) {
      if (text.contains(s)) return 'hindi';
    }
    for (final s in _tamilSingers) {
      if (text.contains(s)) return 'tamil';
    }
    for (final s in _punjabiSingers) {
      if (text.contains(s)) return 'punjabi';
    }

    // 5. English / Western artists
    for (final a in _englishArtists) {
      if (text.contains(a)) return 'english';
    }

    return 'english';
  }

  bool _isLanguageMatch(SongModel candidate, String seedLang) {
    if (seedLang == 'unknown') return true;
    final candidateLang = _inferLanguage(candidate);
    return candidateLang == seedLang;
  }
}
