import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/playlist_model.dart';
import '../../models/song_model.dart';

/// Local persistence contract for Library and Downloads.
/// Strictly adheres to AGENTS.md Invariant 1 (Provider injected, zero singletons).
abstract class StorageDatasource {
  Future<List<SongModel>> getLikedSongs();
  Future<void> saveLikedSongs(List<SongModel> songs);
  Future<bool> toggleLike(SongModel song);
  Stream<List<SongModel>> get likedSongsStream;

  Future<List<PlaylistModel>> getPlaylists();
  Future<void> savePlaylists(List<PlaylistModel> playlists);

  Future<List<SongModel>> getListeningHistory();
  Future<void> saveListeningHistory(List<SongModel> songs);

  Future<List<SongModel>> getDownloadedSongs();
  Future<void> saveDownloadedSongs(List<SongModel> songs);
}

class StorageDatasourceImpl implements StorageDatasource {
  static const _likedKey = 'dilse_liked_songs_v2';
  static const _playlistsKey = 'dilse_custom_playlists_v2';
  static const _historyKey = 'dilse_listening_history_v2';
  static const _downloadsKey = 'dilse_downloaded_songs_v2';
  static const _inbuiltSeededKey = 'dilse_inbuilt_seeded_v1';

  final _likedController = StreamController<List<SongModel>>.broadcast();

  @override
  Stream<List<SongModel>> get likedSongsStream => _likedController.stream;

  @override
  Future<List<SongModel>> getLikedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_likedKey) ?? [];
    if (raw.isEmpty) {
      // Seed initial liked songs from inbuilt playlists so calibrator has user taste anchors immediately
      try {
        final jsonStr = await rootBundle.loadString('assets/inbuilt_playlists.json');
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        final inbuilt = decoded
            .map((p) => PlaylistModel.fromJson(p as Map<String, dynamic>))
            .toList();
        final liked1 = inbuilt.firstWhere((p) => p.id == 'inbuilt_liked1', orElse: () => inbuilt.first);
        final liked2 = inbuilt.firstWhere((p) => p.id == 'inbuilt_liked2', orElse: () => inbuilt.first);
        final allSongs = <String, SongModel>{};
        for (final s in [...liked1.songs, ...liked2.songs]) {
          allSongs[s.id] = s;
        }
        final seeded = allSongs.values.toList();
        if (seeded.isNotEmpty) {
          await saveLikedSongs(seeded);
          return seeded;
        }
      } catch (_) {}
    }
    return raw
        .map((str) => SongModel.fromJson(jsonDecode(str) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveLikedSongs(List<SongModel> songs) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = songs.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_likedKey, raw);
    _likedController.add(List.unmodifiable(songs));
  }

  @override
  Future<bool> toggleLike(SongModel song) async {
    final songs = await getLikedSongs();
    final idx = songs.indexWhere((s) => s.id == song.id);
    final exists = idx != -1;
    if (exists) {
      songs.removeAt(idx);
    } else {
      songs.insert(0, song);
    }
    await saveLikedSongs(songs);
    return !exists;
  }

  @override
  Future<List<PlaylistModel>> getPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final isSeeded = prefs.getBool(_inbuiltSeededKey) ?? false;
    final raw = prefs.getStringList(_playlistsKey) ?? [];

    if (!isSeeded || raw.isEmpty) {
      try {
        final jsonStr = await rootBundle.loadString('assets/inbuilt_playlists.json');
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        final inbuilt = decoded
            .map((p) => PlaylistModel.fromJson(p as Map<String, dynamic>))
            .toList();

        final existing = raw
            .map((str) => PlaylistModel.fromJson(jsonDecode(str) as Map<String, dynamic>))
            .toList();

        final existingIds = existing.map((p) => p.id).toSet();
        final toAdd = inbuilt.where((p) => !existingIds.contains(p.id)).toList();
        final merged = [...toAdd, ...existing];

        await savePlaylists(merged);
        await prefs.setBool(_inbuiltSeededKey, true);
        return merged;
      } catch (_) {
        // Fallback gracefully in test environments if rootBundle assets are not present
      }
    }

    return raw
        .map((str) =>
            PlaylistModel.fromJson(jsonDecode(str) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> savePlaylists(List<PlaylistModel> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = playlists.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(_playlistsKey, raw);
  }

  @override
  Future<List<SongModel>> getListeningHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? [];
    return raw
        .map((str) => SongModel.fromJson(jsonDecode(str) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveListeningHistory(List<SongModel> songs) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = songs.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_historyKey, raw);
  }

  @override
  Future<List<SongModel>> getDownloadedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_downloadsKey) ?? [];
    return raw
        .map((str) => SongModel.fromJson(jsonDecode(str) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveDownloadedSongs(List<SongModel> songs) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = songs.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_downloadsKey, raw);
  }
}

