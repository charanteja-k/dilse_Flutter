import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../data/datasources/local/storage_datasource.dart';
import '../../../data/models/song_model.dart';

/// Pure business ViewModel managing downloaded offline tracks and storage telemetry.
/// Strictly adheres to AGENTS.md Invariants 1 & 3.
class DownloadsViewModel extends ChangeNotifier {
  final StorageDatasource storageDatasource;

  DownloadsViewModel({required this.storageDatasource}) {
    loadDownloadedSongs();
  }

  List<SongModel> _downloadedSongs = [];
  Map<String, int> _songFileSizes = {};
  String _searchFilter = '';
  bool _isLoading = false;

  List<SongModel> get downloadedSongs => List.unmodifiable(_downloadedSongs);
  String get searchFilter => _searchFilter;
  bool get isLoading => _isLoading;

  List<SongModel> get filteredSongs {
    if (_searchFilter.trim().isEmpty) return _downloadedSongs;
    final q = _searchFilter.toLowerCase();
    return _downloadedSongs
        .where(
          (s) =>
              s.title.toLowerCase().contains(q) ||
              s.artist.toLowerCase().contains(q) ||
              s.album.toLowerCase().contains(q),
        )
        .toList();
  }

  int get totalStorageBytes =>
      _songFileSizes.values.fold<int>(0, (sum, sz) => sum + sz);

  String get formattedTotalStorage => formatBytes(totalStorageBytes);

  String formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void updateSearchFilter(String query) {
    _searchFilter = query;
    notifyListeners();
  }

  Future<void> loadDownloadedSongs() async {
    _isLoading = true;
    notifyListeners();

    try {
      _downloadedSongs = await storageDatasource.getDownloadedSongs();
      await _calculateFileSizes();
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _calculateFileSizes() async {
    if (kIsWeb) return;
    _songFileSizes = {};
    for (final song in _downloadedSongs) {
      if (song.streamUrl.isNotEmpty && song.streamUrl.startsWith('/')) {
        try {
          final file = File(song.streamUrl);
          if (await file.exists()) {
            _songFileSizes[song.id] = await file.length();
          }
        } catch (_) {}
      }
    }
  }

  Future<void> addDownload(SongModel song, {int fileSizeBytes = 0}) async {
    if (!_downloadedSongs.any((s) => s.id == song.id)) {
      _downloadedSongs.insert(0, song);
      if (fileSizeBytes > 0) {
        _songFileSizes[song.id] = fileSizeBytes;
      }
      notifyListeners();
      await storageDatasource.saveDownloadedSongs(_downloadedSongs);
    }
  }

  Future<void> removeDownload(String songId) async {
    final idx = _downloadedSongs.indexWhere((s) => s.id == songId);
    if (idx != -1) {
      final song = _downloadedSongs[idx];
      _downloadedSongs.removeAt(idx);
      _songFileSizes.remove(songId);

      // Attempt local file cleanup
      if (!kIsWeb && song.streamUrl.startsWith('/')) {
        try {
          final file = File(song.streamUrl);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }

      notifyListeners();
      await storageDatasource.saveDownloadedSongs(_downloadedSongs);
    }
  }
}
