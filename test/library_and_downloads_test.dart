import 'package:flutter_test/flutter_test.dart';
import 'package:dilse/data/datasources/local/storage_datasource.dart';
import 'package:dilse/data/models/playlist_model.dart';
import 'package:dilse/data/models/song_model.dart';
import 'package:dilse/features/library/viewmodels/library_viewmodel.dart';
import 'package:dilse/features/downloads/viewmodels/downloads_viewmodel.dart';

class FakeStorageDatasource implements StorageDatasource {
  List<SongModel> liked = [];
  List<PlaylistModel> playlists = [];
  List<SongModel> history = [];
  List<SongModel> downloads = [];

  @override
  Future<List<SongModel>> getLikedSongs() async => List.from(liked);

  @override
  Future<void> saveLikedSongs(List<SongModel> songs) async {
    liked = List.from(songs);
  }

  @override
  Future<List<PlaylistModel>> getPlaylists() async => List.from(playlists);

  @override
  Future<void> savePlaylists(List<PlaylistModel> list) async {
    playlists = List.from(list);
  }

  @override
  Future<List<SongModel>> getListeningHistory() async => List.from(history);

  @override
  Future<void> saveListeningHistory(List<SongModel> songs) async {
    history = List.from(songs);
  }

  @override
  Future<List<SongModel>> getDownloadedSongs() async => List.from(downloads);

  @override
  Future<void> saveDownloadedSongs(List<SongModel> songs) async {
    downloads = List.from(songs);
  }
}

void main() {
  const sampleSong1 = SongModel(
    id: 's1',
    title: 'Samajavaragamana',
    artist: 'Sid Sriram',
    album: 'Ala Vaikunthapurramuloo',
    streamUrl: 'https://cdn.dilse.app/s1.m4a',
    thumbnailUrl: 'https://cdn.dilse.app/s1.jpg',
    duration: Duration(seconds: 215),
  );

  const sampleSong2 = SongModel(
    id: 's2',
    title: 'Kesariya',
    artist: 'Arijit Singh',
    album: 'Brahmastra',
    streamUrl: 'https://cdn.dilse.app/s2.m4a',
    thumbnailUrl: 'https://cdn.dilse.app/s2.jpg',
    duration: Duration(seconds: 268),
  );

  group('LibraryViewModel Tests', () {
    test('Toggle like adds and removes songs correctly', () async {
      final storage = FakeStorageDatasource();
      final vm = LibraryViewModel(storageDatasource: storage);
      await vm.loadLibrary();

      expect(vm.likedSongs, isEmpty);
      expect(vm.isLiked(sampleSong1.id), isFalse);

      // Like song 1
      await vm.toggleLike(sampleSong1);
      expect(vm.likedSongs.length, 1);
      expect(vm.isLiked(sampleSong1.id), isTrue);

      // Unlike song 1
      await vm.toggleLike(sampleSong1);
      expect(vm.likedSongs, isEmpty);
      expect(vm.isLiked(sampleSong1.id), isFalse);
    });

    test('Playlist CRUD operates cleanly', () async {
      final storage = FakeStorageDatasource();
      final vm = LibraryViewModel(storageDatasource: storage);
      await vm.loadLibrary();

      await vm.createPlaylist('Late Night Vibe');
      expect(vm.playlists.length, 1);
      expect(vm.playlists.first.title, 'Late Night Vibe');

      final plId = vm.playlists.first.id;

      // Add song to playlist
      await vm.addSongToPlaylist(plId, sampleSong1);
      expect(vm.playlists.first.songCount, 1);

      // Remove song from playlist
      await vm.removeSongFromPlaylist(plId, sampleSong1.id);
      expect(vm.playlists.first.songCount, 0);

      // Delete playlist
      await vm.deletePlaylist(plId);
      expect(vm.playlists, isEmpty);
    });

    test('Derived albums and artists aggregate from library tracks', () async {
      final storage = FakeStorageDatasource();
      final vm = LibraryViewModel(storageDatasource: storage);
      await vm.loadLibrary();

      await vm.toggleLike(sampleSong1);
      await vm.toggleLike(sampleSong2);

      expect(
        vm.derivedAlbums,
        containsAll(['Ala Vaikunthapurramuloo', 'Brahmastra']),
      );
      expect(vm.derivedArtists, containsAll(['Sid Sriram', 'Arijit Singh']));
    });
  });

  group('DownloadsViewModel Tests', () {
    test('Downloads management and storage telemetry formatting', () async {
      final storage = FakeStorageDatasource();
      final vm = DownloadsViewModel(storageDatasource: storage);
      await vm.loadDownloadedSongs();

      expect(vm.downloadedSongs, isEmpty);
      expect(vm.formattedTotalStorage, '0 MB');

      // Add downloaded song with 12MB size
      await vm.addDownload(sampleSong1, fileSizeBytes: 12 * 1024 * 1024);
      expect(vm.downloadedSongs.length, 1);
      expect(vm.formattedTotalStorage, '12.0 MB');

      // Filter query test
      vm.updateSearchFilter('samaja');
      expect(vm.filteredSongs.length, 1);

      vm.updateSearchFilter('nonexistent');
      expect(vm.filteredSongs, isEmpty);

      // Remove download
      await vm.removeDownload(sampleSong1.id);
      expect(vm.downloadedSongs, isEmpty);
      expect(vm.formattedTotalStorage, '0 MB');
    });
  });
}
