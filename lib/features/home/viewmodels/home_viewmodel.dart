import 'package:flutter/foundation.dart';
import '../../../data/models/circadian_context.dart';
import '../../../data/models/mood_category.dart';
import '../../../data/models/quick_access_item.dart';
import '../../../data/models/song_model.dart';
import '../../../data/repositories/audio_repository.dart';

/// ViewModel managing the complete DilSe Home Feed presentation state.
/// Follows strict MVVM Protocol & AGENTS.md:
/// - Invariant 1: Injected via Provider, strictly zero static singletons.
/// - Invariant 3: Coordinates data sources and emits state, zero widget references.
class HomeViewModel extends ChangeNotifier {
  final AudioRepository audioRepository;

  String _selectedLanguage = 'Telugu';
  int _selectedMoodIndex = 0;
  bool _isLoading = false;
  bool _isLoadingVibe = false;
  bool _isDisposed = false;
  bool _isQuickResumeDismissed = false;
  String? _errorMessage;

  int _loadEpoch = 0;
  int _vibeEpoch = 0;

  CircadianContext _circadianContext;
  SongModel? _quickResumeSong;

  List<QuickAccessItem> _quickAccessItems = [];
  List<SongModel> _circadianMix = [];
  List<SongModel> _topChartsIndia = [];
  List<SongModel> _blockbusterAlbums = [];
  List<SongModel> _madeForYou = [];
  List<SongModel> _vibeRadioTracks = [];

  final Map<int, List<SongModel>> _vibeCache = {};

  HomeViewModel({required this.audioRepository})
      : _circadianContext = CircadianContext.fromHour(DateTime.now().hour, primaryLanguage: 'Telugu');

  // Getters
  String get selectedLanguage => _selectedLanguage;
  int get selectedMoodIndex => _selectedMoodIndex;
  bool get isLoading => _isLoading;
  bool get isLoadingVibe => _isLoadingVibe;
  String? get errorMessage => _errorMessage;

  CircadianContext get circadianContext => _circadianContext;
  SongModel? get quickResumeSong => _isQuickResumeDismissed ? null : _quickResumeSong;

  List<QuickAccessItem> get quickAccessItems => List.unmodifiable(_quickAccessItems);
  List<SongModel> get circadianMix => List.unmodifiable(_circadianMix);
  List<SongModel> get topChartsIndia => List.unmodifiable(_topChartsIndia);
  List<SongModel> get blockbusterAlbums => List.unmodifiable(_blockbusterAlbums);
  List<SongModel> get madeForYou => List.unmodifiable(_madeForYou);
  List<SongModel> get vibeRadioTracks => List.unmodifiable(_vibeRadioTracks);

  final List<String> availableLanguages = const [
    'Telugu',
    'Hindi',
    'Tamil',
    'English',
    'Punjabi',
  ];

  final List<MoodCategory> moodCategories = const [
    MoodCategory(
      label: 'All Hits',
      queryTemplate: '{lang} Top Hits',
      description: 'All trending and personalized hits curated for you',
    ),
    MoodCategory(
      label: 'Energetic',
      queryTemplate: '{lang} Fast Hits',
      description: 'High-tempo power anthems to fuel your energy',
    ),
    MoodCategory(
      label: 'Chill & Relax',
      queryTemplate: '{lang} Melodies',
      description: 'Mellow acoustic melodies to unwind and relax',
    ),
    MoodCategory(
      label: 'Focus & Code',
      queryTemplate: 'Lofi Instrumental Chill Beats',
      description: 'Smooth non-distracting instrumental beats for flow state',
    ),
    MoodCategory(
      label: 'Workout',
      queryTemplate: '{lang} Mass Hits',
      description: 'Adrenaline-pumping tracks to power your training session',
    ),
    MoodCategory(
      label: 'Sleep',
      queryTemplate: '{lang} Slow Melodies',
      description: 'Peaceful, dreamy soundscapes for deep and restful sleep',
    ),
    MoodCategory(
      label: 'Party Hits',
      queryTemplate: '{lang} Party Hits',
      description: 'Dancefloor crowd-pleasers and club anthems',
    ),
  ];

  List<String> get availableMoods => moodCategories.map((m) => m.label).toList(growable: false);

  MoodCategory get activeMoodCategory => moodCategories[_selectedMoodIndex.clamp(0, moodCategories.length - 1)];

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> loadHomeFeed({String? language}) async {
    if (language != null) {
      _selectedLanguage = language;
      _vibeCache.clear();
    }

    final currentEpoch = ++_loadEpoch;

    _circadianContext = CircadianContext.fromHour(
      DateTime.now().hour,
      primaryLanguage: _selectedLanguage,
    );

    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      // Concurrently fetch all home feed sections matching legacy music_app pipeline
      final results = await Future.wait([
        // Daily Mix 1 seed
        audioRepository.searchSongs('$_selectedLanguage Mix', limit: 12),
        // Daily Mix 2 seed
        audioRepository.searchSongs('$_selectedLanguage Acoustic Chill', limit: 12),
        // Nostalgic mix seed (Slot 4)
        audioRepository.searchSongs('$_selectedLanguage Retro Classics 90s 2000s', limit: 12),
        // Circadian time-of-day contextual shelf
        audioRepository.searchSongs(_circadianContext.query, limit: 14),
        // Top Charts India
        audioRepository.searchSongs('Top Charts India $_selectedLanguage', limit: 14),
        // Blockbuster Soundtracks & Albums
        audioRepository.searchSongs('$_selectedLanguage Latest Movie Soundtracks', limit: 14),
        // Made For You (Algorithmic radar)
        audioRepository.getRecommendations(query: _selectedLanguage.toLowerCase(), limit: 14),
        // Trending Now seed (Slot 6)
        audioRepository.searchSongs('$_selectedLanguage Trending Hits', limit: 12),
      ]);

      if (_isDisposed || currentEpoch != _loadEpoch) return;

      final mix1Songs = results[0];
      final mix2Songs = results[1];
      final nostalgicSongs = results[2];
      _circadianMix = results[3];
      _topChartsIndia = results[4];
      _blockbusterAlbums = results[5];
      _madeForYou = results[6];
      final trendingSongs = results[7];

      // Synthesize the 2x3 Quick Access Grid items
      //Note: Liked Songs & Personalized Playlist history parsing will connect in local storage phase.
      _quickAccessItems = [
        QuickAccessItem(
          id: 'daily_mix_1',
          title: 'Daily Mix 1',
          subtitle: '$_selectedLanguage Mix',
          iconKey: 'daily_mix_1',
          imageUrl: mix1Songs.isNotEmpty ? mix1Songs.first.thumbnailUrl : null,
          songs: mix1Songs,
        ),
        QuickAccessItem(
          id: 'liked_songs',
          title: 'Liked Songs',
          subtitle: 'Favorites & Hearted',
          iconKey: 'liked_songs',
          imageUrl: null,
          songs: const [],
        ),
        QuickAccessItem(
          id: 'daily_mix_2',
          title: 'Daily Mix 2',
          subtitle: 'Acoustic & Chill',
          iconKey: 'daily_mix_2',
          imageUrl: mix2Songs.isNotEmpty ? mix2Songs.first.thumbnailUrl : null,
          songs: mix2Songs,
        ),
        QuickAccessItem(
          id: 'nostalgic',
          title: 'Nostalgic',
          subtitle: 'Forgotten favorites & deep cuts',
          iconKey: 'nostalgic',
          imageUrl: nostalgicSongs.isNotEmpty ? nostalgicSongs.first.thumbnailUrl : null,
          songs: nostalgicSongs,
        ),
        QuickAccessItem(
          id: 'top_charts_india',
          title: 'Top Charts India',
          subtitle: 'Updated Daily',
          iconKey: 'top_charts',
          imageUrl: _topChartsIndia.isNotEmpty ? _topChartsIndia.first.thumbnailUrl : null,
          songs: _topChartsIndia,
        ),
        QuickAccessItem(
          id: 'trending_now',
          title: 'Trending Now',
          subtitle: 'Global & Regional Hits',
          iconKey: 'trending',
          imageUrl: trendingSongs.isNotEmpty ? trendingSongs.first.thumbnailUrl : null,
          songs: trendingSongs,
        ),
      ];

      // Placeholder resume target until local playback history persistence is connected
      if (_quickResumeSong == null && _topChartsIndia.isNotEmpty) {
        _quickResumeSong = _topChartsIndia.first;
      }

      _isLoading = false;
      _safeNotify();
    } catch (e) {
      if (_isDisposed || currentEpoch != _loadEpoch) return;
      _errorMessage = 'Failed to load home feed: $e';
      _isLoading = false;
      _safeNotify();
    }
  }

  void selectLanguage(String language) {
    if (_selectedLanguage == language) return;
    _selectedLanguage = language;
    loadHomeFeed(language: language);
  }

  Future<void> selectMood(int index) async {
    if (index < 0 || index >= moodCategories.length) return;
    if (_selectedMoodIndex == index) return;

    _selectedMoodIndex = index;
    final currentVibeEpoch = ++_vibeEpoch;

    if (index == 0) {
      _isLoadingVibe = false;
      _safeNotify();
      return;
    }

    final cached = _vibeCache[index];
    if (cached != null) {
      _vibeRadioTracks = cached;
      _isLoadingVibe = false;
      _safeNotify();
      return;
    }

    final mood = moodCategories[index];
    _isLoadingVibe = true;
    _vibeRadioTracks = [];
    _safeNotify();

    try {
      final rawSongs = await audioRepository.searchSongs(
        mood.resolveQuery(_selectedLanguage),
        limit: 25,
      );
      if (_isDisposed || currentVibeEpoch != _vibeEpoch) return;

      // Filter out ultra-short clips (<45s) or hour-long DJ mixes (>10m)
      final filtered = rawSongs.where((song) {
        final secs = song.duration.inSeconds;
        if (secs <= 0) return true;
        return secs >= 45 && secs <= 600;
      }).toList();

      _vibeCache[index] = filtered;
      _vibeRadioTracks = filtered;
    } catch (_) {
      if (_isDisposed || currentVibeEpoch != _vibeEpoch) return;
      _vibeRadioTracks = [];
    } finally {
      if (!_isDisposed && currentVibeEpoch == _vibeEpoch) {
        _isLoadingVibe = false;
        _safeNotify();
      }
    }
  }

  List<SongModel> buildShuffledVibeQueue() {
    final copy = List<SongModel>.from(_vibeRadioTracks);
    copy.shuffle();
    return copy;
  }

  void setQuickResumeSong(SongModel song) {
    _quickResumeSong = song;
    _isQuickResumeDismissed = false;
    _safeNotify();
  }

  void dismissQuickResume() {
    _isQuickResumeDismissed = true;
    _safeNotify();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
