import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dilse/data/models/playlist_model.dart';

void main() {
  test('Inbuilt Playlists JSON structure and song counts verification', () {
    final file = File('assets/inbuilt_playlists.json');
    expect(file.existsSync(), isTrue, reason: 'assets/inbuilt_playlists.json must exist');

    final jsonStr = file.readAsStringSync();
    final decoded = jsonDecode(jsonStr) as List<dynamic>;

    expect(decoded.length, equals(5), reason: 'Must contain 5 inbuilt playlists: liked1 through liked5');

    final playlists = decoded
        .map((p) => PlaylistModel.fromJson(p as Map<String, dynamic>))
        .toList();

    final titles = playlists.map((p) => p.title).toList();
    expect(titles, equals(['liked1', 'liked2', 'liked3', 'liked4', 'liked5']));

    final liked1 = playlists.firstWhere((p) => p.title == 'liked1');
    final liked2 = playlists.firstWhere((p) => p.title == 'liked2');
    final liked3 = playlists.firstWhere((p) => p.title == 'liked3');
    final liked4 = playlists.firstWhere((p) => p.title == 'liked4');
    final liked5 = playlists.firstWhere((p) => p.title == 'liked5');

    // Combination playlists (liked1 & liked2)
    expect(liked1.songs.length, greaterThan(350));
    expect(liked2.songs.length, greaterThan(350));

    // Language-specific playlists
    expect(liked3.songs.length, greaterThan(300), reason: 'liked3 (Telugu) must have 300+ songs');
    expect(liked4.songs.length, greaterThan(150), reason: 'liked4 (Hindi) must have 150+ songs');
    expect(liked5.songs.length, greaterThan(150), reason: 'liked5 (English) must have 150+ songs');

    // Verify all songs have valid IDs and non-empty titles
    for (final pl in playlists) {
      for (final s in pl.songs) {
        expect(s.id.isNotEmpty, isTrue);
        expect(s.title.isNotEmpty, isTrue);
        expect(s.artist.isNotEmpty, isTrue);
      }
    }
  });
}

