import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/playlist_model.dart';
import '../../models/song_model.dart';

/// Local persistence contract for Library and Downloads.
/// Strictly adheres to AGENTS.md Invariant 1 (Provider injected, zero singletons).
abstract class StorageDatasource {
  Future<List<SongModel>> getLikedSongs();
  Future<void> saveLikedSongs(List<SongModel> songs);

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

  @override
  Future<List<SongModel>> getLikedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_likedKey) ?? [];
    return raw
        .map((str) => SongModel.fromJson(jsonDecode(str) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveLikedSongs(List<SongModel> songs) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = songs.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_likedKey, raw);
  }

  @override
  Future<List<PlaylistModel>> getPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_playlistsKey) ?? [];
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

