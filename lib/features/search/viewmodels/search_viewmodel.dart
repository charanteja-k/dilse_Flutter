import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../data/models/album_model.dart';
import '../../../data/models/artist_model.dart';
import '../../../data/models/song_model.dart';
import '../../../data/repositories/audio_repository.dart';

/// Available sub-category filters for active search query results.
enum SearchFilter {
  all('All Results'),
  tracks('Tracks'),
  artists('Artists'),
  albums('Albums');

  final String label;
  const SearchFilter(this.label);
}

/// Curated browse genre / mood category for the empty/explore state.
@immutable
class SearchCategory {
  final String id;
  final String title;
  final String subtitle;
  final String query;
  final String glyph;

  const SearchCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.query,
    required this.glyph,
  });
}

/// Pure business ViewModel managing song, album, and artist search, debounce orchestration, and history.
/// Strictly adheres to AGENTS.md:
/// - Invariant 1: Injected via Provider/MultiProvider (strictly zero static singletons).
/// - Invariant 3: Strict MVVM (Zero BuildContext references, zero Flutter UI dependencies).
class SearchViewModel extends ChangeNotifier {
  final AudioRepository audioRepository;

  SearchViewModel({required this.audioRepository});

  String _query = '';
  List<SongModel> _searchResults = [];
  List<AlbumModel> _albumResults = [];
  List<ArtistModel> _artistResults = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounceTimer;
  SearchFilter _selectedFilter = SearchFilter.all;

  final List<String> _recentSearches = [
    'Samajavaragamana',
    'Kesariya',
    'Chuttamalle',
    'Inkem Inkem',
    'Arabic Kuthu',
    'Butta Bomma',
    'Naatu Naatu',
    'Shape of You',
  ];

  static const List<SearchCategory> _categories = [
    SearchCategory(
      id: 'telugu',
      title: 'Telugu Hits',
      subtitle: 'Tollywood Chartbusters ⚡',
      query: 'Telugu Top Hits',
      glyph: '⚡',
    ),
    SearchCategory(
      id: 'hindi',
      title: 'Hindi Melodies',
      subtitle: 'Romantic & Soulful 🌙',
      query: 'Hindi Romantic Hits',
      glyph: '🌙',
    ),
    SearchCategory(
      id: 'tamil',
      title: 'Tamil Local',
      subtitle: 'High-BPM Anthems 🔥',
      query: 'Tamil Mass Hits',
      glyph: '🔥',
    ),
    SearchCategory(
      id: 'lofi',
      title: 'Lo-Fi State',
      subtitle: 'Chill Coding Beats 🎧',
      query: 'Lofi Instrumental Chill Beats',
      glyph: '🎧',
    ),
    SearchCategory(
      id: 'acoustic',
      title: 'Acoustic Café',
      subtitle: 'Unplugged & Raw ☕',
      query: 'Acoustic Unplugged Melodies',
      glyph: '☕',
    ),
    SearchCategory(
      id: 'workout',
      title: 'Gym Workout',
      subtitle: 'Adrenaline Pump 💥',
      query: 'Workout Motivation Hits',
      glyph: '💥',
    ),
    SearchCategory(
      id: 'devotional',
      title: 'Devotional',
      subtitle: 'Spiritual Peace 🪔',
      query: 'Devotional Spiritual Songs',
      glyph: '🪔',
    ),
    SearchCategory(
      id: 'global',
      title: 'Global Top 50',
      subtitle: 'Trending Worldwide 🌍',
      query: 'Global Viral Top Hits',
      glyph: '🌍',
    ),
  ];

  String get query => _query;
  List<SongModel> get searchResults => List.unmodifiable(_searchResults);
  List<AlbumModel> get albumResults => List.unmodifiable(_albumResults);
  List<ArtistModel> get artistResults => List.unmodifiable(_artistResults);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<String> get recentSearches => List.unmodifiable(_recentSearches);
  List<SearchCategory> get categories => _categories;
  SearchFilter get selectedFilter => _selectedFilter;
  bool get hasResults => _searchResults.isNotEmpty || _albumResults.isNotEmpty || _artistResults.isNotEmpty;

  /// Returns results filtered according to the active [SearchFilter].
  List<SongModel> get filteredResults {
    switch (_selectedFilter) {
      case SearchFilter.all:
      case SearchFilter.tracks:
        return _searchResults;
      case SearchFilter.artists:
        final q = _query.toLowerCase();
        final matches = _searchResults.where((s) => s.artist.toLowerCase().contains(q)).toList();
        return matches.isNotEmpty ? matches : _searchResults;
      case SearchFilter.albums:
        final q = _query.toLowerCase();
        final matches = _searchResults.where((s) => s.album.toLowerCase().contains(q)).toList();
        return matches.isNotEmpty ? matches : _searchResults;
    }
  }

  /// Top #1 matching track for the dedicated Spotlight card.
  SongModel? get topResult => filteredResults.isNotEmpty ? filteredResults.first : null;

  /// Remaining track list excluding the top spotlight track.
  List<SongModel> get remainingResults {
    final list = filteredResults;
    if (list.length <= 1) return const [];
    return list.sublist(1);
  }

  void setFilter(SearchFilter filter) {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
    notifyListeners();
  }

  void onQueryChanged(String newQuery) {
    _query = newQuery;
    _debounceTimer?.cancel();

    if (newQuery.trim().isEmpty) {
      _searchResults = [];
      _albumResults = [];
      _artistResults = [];
      _isLoading = false;
      _errorMessage = null;
      _selectedFilter = SearchFilter.all;
      notifyListeners();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      search(newQuery);
    });
  }

  Future<void> search(String queryText) async {
    final cleanQuery = queryText.trim();
    if (cleanQuery.isEmpty) return;

    _query = cleanQuery;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final songFuture = audioRepository.searchSongs(cleanQuery, limit: 35);
      final albumFuture = audioRepository.searchAlbums(cleanQuery, limit: 15);
      final artistFuture = audioRepository.searchArtists(cleanQuery, limit: 15);

      final results = await Future.wait([
        songFuture,
        albumFuture,
        artistFuture,
      ]);

      _searchResults = results[0] as List<SongModel>;
      _albumResults = results[1] as List<AlbumModel>;
      _artistResults = results[2] as List<ArtistModel>;

      if (!_recentSearches.contains(cleanQuery)) {
        _recentSearches.insert(0, cleanQuery);
        if (_recentSearches.length > 15) {
          _recentSearches.removeLast();
        }
      }
    } catch (e) {
      _errorMessage = 'Search error: $e';
      _searchResults = [];
      _albumResults = [];
      _artistResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    _query = '';
    _searchResults = [];
    _albumResults = [];
    _artistResults = [];
    _isLoading = false;
    _errorMessage = null;
    _selectedFilter = SearchFilter.all;
    notifyListeners();
  }

  void removeRecentSearch(String item) {
    _recentSearches.remove(item);
    notifyListeners();
  }

  void clearAllRecentSearches() {
    _recentSearches.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

