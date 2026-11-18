import 'package:flutter/foundation.dart';
import '../../../data/models/album_model.dart';
import '../../../data/models/artist_model.dart';
import '../../../data/models/song_model.dart';
import '../../../data/repositories/audio_repository.dart';

enum ArtistFilter {
  all,
  topTracks,
  albums,
}

/// ViewModel managing artist profile state, top tracks, and discography albums.
/// Follows AGENTS.md:
/// - Invariant 1: Provider & Streams only (strictly zero static singletons).
/// - Invariant 3: Strict MVVM (Zero widget/BuildContext references, cancels async ops).
class ArtistDetailViewModel extends ChangeNotifier {
  final AudioRepository audioRepository;
  final ArtistModel artist;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<SongModel> _topSongs = [];
  List<SongModel> get topSongs => _topSongs;

  List<AlbumModel> _topAlbums = [];
  List<AlbumModel> get topAlbums => _topAlbums;

  int _followerCount = 0;
  int get followerCount => _followerCount;

  ArtistFilter _currentFilter = ArtistFilter.all;
  ArtistFilter get currentFilter => _currentFilter;

  bool _isDisposed = false;

  ArtistDetailViewModel({
    required this.audioRepository,
    required this.artist,
  }) {
    fetchArtistDetails();
  }

  void setFilter(ArtistFilter filter) {
    if (_currentFilter == filter) return;
    _currentFilter = filter;
    notifyListeners();
  }

  Future<void> fetchArtistDetails() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final details = await audioRepository.getArtistDetails(artist.id);
      if (_isDisposed) return;
      _topSongs = details.topSongs;
      _topAlbums = details.topAlbums;
      _followerCount = details.followerCount;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (_isDisposed) return;
      _isLoading = false;
      _errorMessage = 'Failed to load artist details. Please try again.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

