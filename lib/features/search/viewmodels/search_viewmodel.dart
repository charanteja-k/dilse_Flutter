import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../data/models/song_model.dart';
import '../../../data/repositories/audio_repository.dart';

/// Pure business ViewModel managing song search, debounce orchestration, and search history.
/// Strictly adheres to AGENTS.md:
/// - Invariant 1: Injected via Provider/MultiProvider (strictly zero static singletons).
/// - Invariant 3: Strict MVVM (Zero BuildContext references, zero Flutter UI dependencies).
class SearchViewModel extends ChangeNotifier {
  final AudioRepository audioRepository;

  SearchViewModel({required this.audioRepository});

  String _query = '';
  List<SongModel> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounceTimer;

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

  String get query => _query;
  List<SongModel> get searchResults => List.unmodifiable(_searchResults);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<String> get recentSearches => List.unmodifiable(_recentSearches);
  bool get hasResults => _searchResults.isNotEmpty;

  void onQueryChanged(String newQuery) {
    _query = newQuery;
    _debounceTimer?.cancel();

    if (newQuery.trim().isEmpty) {
      _searchResults = [];
      _isLoading = false;
      _errorMessage = null;
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
      final results = await audioRepository.searchSongs(cleanQuery, limit: 30);
      _searchResults = results;

      if (!_recentSearches.contains(cleanQuery)) {
        _recentSearches.insert(0, cleanQuery);
        if (_recentSearches.length > 15) {
          _recentSearches.removeLast();
        }
      }
    } catch (e) {
      _errorMessage = 'Search error: $e';
      _searchResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    _query = '';
    _searchResults = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void removeRecentSearch(String item) {
    _recentSearches.remove(item);
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

