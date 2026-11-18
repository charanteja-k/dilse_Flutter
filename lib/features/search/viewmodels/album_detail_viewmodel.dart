import 'package:flutter/foundation.dart';
import '../../../data/models/album_model.dart';
import '../../../data/models/song_model.dart';
import '../../../data/repositories/audio_repository.dart';

/// ViewModel managing album details and tracklist state.
/// Follows AGENTS.md:
/// - Invariant 1: Provider & Streams only (strictly zero static singletons).
/// - Invariant 3: Strict MVVM (Zero widget/BuildContext references, cancels async ops).
class AlbumDetailViewModel extends ChangeNotifier {
  final AudioRepository audioRepository;
  final AlbumModel album;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<SongModel> _tracks = [];
  List<SongModel> get tracks => _tracks;

  bool _isDisposed = false;

  AlbumDetailViewModel({required this.audioRepository, required this.album}) {
    fetchAlbumTracks();
  }

  Future<void> fetchAlbumTracks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await audioRepository.getAlbumDetails(album.id);
      if (_isDisposed) return;
      _tracks = results;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (_isDisposed) return;
      _isLoading = false;
      _errorMessage = 'Failed to load album tracks. Please try again.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
