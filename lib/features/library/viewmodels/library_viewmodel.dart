import 'package:flutter/foundation.dart';
import '../../../data/datasources/local/storage_datasource.dart';
import '../../../data/models/playlist_model.dart';
import '../../../data/models/song_model.dart';

enum LibrarySection { playlists, liked, albums, artists, history }

extension LibrarySectionExt on LibrarySection {
  String get label {
    switch (this) {
      case LibrarySection.playlists:
        return 'Playlists';
      case LibrarySection.liked:
        return 'Liked Songs';
      case LibrarySection.albums:
        return 'Albums';
      case LibrarySection.artists:
        return 'Artists';
      case LibrarySection.history:
        return 'History';
    }
  }
}

/// Pure business ViewModel managing the user's Library state.
/// Strictly adheres to AGENTS.md:
/// - Invariant 1: Provider injected, zero singletons.
/// - Invariant 3: Strict MVVM (zero BuildContext, zero UI widgets).
class LibraryViewModel extends ChangeNotifier {
  final StorageDatasource storageDatasource;

  LibraryViewModel({required this.storageDatasource}) {
    loadLibrary();
  }

  LibrarySection _currentSection = LibrarySection.playlists;
  List<PlaylistModel> _playlists = [];
  List<SongModel> _likedSongs = [];
  List<SongModel> _history = [];
  bool _isLoading = false;

  LibrarySection get currentSection => _currentSection;
  List<PlaylistModel> get playlists => List.unmodifiable(_playlists);
  List<SongModel> get likedSongs => List.unmodifiable(_likedSongs);
  List<SongModel> get history => List.unmodifiable(_history);
  bool get isLoading => _isLoading;

  bool isLiked(String songId) => _likedSongs.any((s) => s.id == songId);

  List<String> get derivedAlbums {
    final all = [..._likedSongs, ..._history];
    for (final p in _playlists) {
      all.addAll(p.songs);
    }
    return all
        .map((s) => s.album.trim())
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> get derivedArtists {
    final all = [..._likedSongs, ..._history];
    for (final p in _playlists) {
      all.addAll(p.songs);
    }
    return all
        .map((s) => s.artist.trim())
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList();
  }

  void selectSection(LibrarySection section) {
    if (_currentSection != section) {
      _currentSection = section;
      notifyListeners();
    }
  }

  Future<void> loadLibrary() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        storageDatasource.getPlaylists(),
        storageDatasource.getLikedSongs(),
        storageDatasource.getListeningHistory(),
      ]);

      _playlists = results[0] as List<PlaylistModel>;
      _likedSongs = results[1] as List<SongModel>;
      _history = results[2] as List<SongModel>;
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(SongModel song) async {
    final exists = _likedSongs.any((s) => s.id == song.id);
    if (exists) {
      _likedSongs.removeWhere((s) => s.id == song.id);
    } else {
      _likedSongs.insert(0, song);
    }
    notifyListeners();
    await storageDatasource.saveLikedSongs(_likedSongs);
  }

  Future<void> addToHistory(SongModel song) async {
    _history.removeWhere((s) => s.id == song.id);
    _history.insert(0, song);
    if (_history.length > 50) {
      _history.removeLast();
    }
    notifyListeners();
    await storageDatasource.saveListeningHistory(_history);
  }

  Future<void> createPlaylist(String title, {String description = ''}) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return;

    final newPlaylist = PlaylistModel(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      title: cleanTitle,
      description: description.trim(),
      createdAt: DateTime.now(),
    );

    _playlists.insert(0, newPlaylist);
    notifyListeners();
    await storageDatasource.savePlaylists(_playlists);
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
    notifyListeners();
    await storageDatasource.savePlaylists(_playlists);
  }

  Future<void> addSongToPlaylist(String playlistId, SongModel song) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final target = _playlists[idx];
      if (!target.songs.any((s) => s.id == song.id)) {
        final updated = target.copyWith(
          songs: [...target.songs, song],
          thumbnailUrl: target.thumbnailUrl.isEmpty
              ? song.thumbnailUrl
              : target.thumbnailUrl,
        );
        _playlists[idx] = updated;
        notifyListeners();
        await storageDatasource.savePlaylists(_playlists);
      }
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final target = _playlists[idx];
      final updated = target.copyWith(
        songs: target.songs.where((s) => s.id != songId).toList(),
      );
      _playlists[idx] = updated;
      notifyListeners();
      await storageDatasource.savePlaylists(_playlists);
    }
  }
}
