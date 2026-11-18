import 'package:flutter_test/flutter_test.dart';
import 'package:dilse/data/models/album_model.dart';
import 'package:dilse/data/models/artist_model.dart';
import 'package:dilse/data/models/song_model.dart';
import 'package:dilse/data/repositories/audio_repository.dart';
import 'package:dilse/features/search/viewmodels/search_viewmodel.dart';

class MockAudioRepository implements AudioRepository {
  List<SongModel> mockResults = [];

  @override
  Future<List<SongModel>> searchSongs(
    String query, {
    int limit = 20,
    int page = 1,
  }) async {
    return mockResults;
  }

  @override
  Future<List<AlbumModel>> searchAlbums(
    String query, {
    int limit = 15,
    int page = 1,
  }) async {
    return [];
  }

  @override
  Future<List<ArtistModel>> searchArtists(
    String query, {
    int limit = 15,
    int page = 1,
  }) async {
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SongModel createTestSong(String id, String title, String artist, String album) {
  return SongModel(
    id: id,
    title: title,
    artist: artist,
    album: album,
    thumbnailUrl: 'https://example.com/art.jpg',
    streamUrl: 'https://example.com/audio.m4a',
    duration: const Duration(minutes: 3, seconds: 45),
  );
}

void main() {
  late MockAudioRepository mockRepo;
  late SearchViewModel viewModel;

  setUp(() {
    mockRepo = MockAudioRepository();
    viewModel = SearchViewModel(audioRepository: mockRepo);
  });

  group('SearchViewModel Editorial Spotlight Tests', () {
    test('Initial explore state exposes categories and default filters', () {
      expect(viewModel.categories.length, equals(8));
      expect(viewModel.categories.first.title, equals('Telugu Hits'));
      expect(viewModel.selectedFilter, equals(SearchFilter.all));
      expect(viewModel.query, isEmpty);
      expect(viewModel.hasResults, isFalse);
    });

    test('Recent searches clear and remove works seamlessly', () {
      final initialCount = viewModel.recentSearches.length;
      expect(initialCount, greaterThan(0));

      final firstItem = viewModel.recentSearches.first;
      viewModel.removeRecentSearch(firstItem);
      expect(viewModel.recentSearches.contains(firstItem), isFalse);
      expect(viewModel.recentSearches.length, equals(initialCount - 1));

      viewModel.clearAllRecentSearches();
      expect(viewModel.recentSearches, isEmpty);
    });

    test('Top Result and Remaining Results partition correctly', () async {
      final song1 = createTestSong(
        '1',
        'Samajavaragamana',
        'Sid Sriram',
        'Ala Vaikunthapurramuloo',
      );
      final song2 = createTestSong(
        '2',
        'Ramuloo Ramulaa',
        'Anurag Kulkarni',
        'Ala Vaikunthapurramuloo',
      );
      final song3 = createTestSong(
        '3',
        'Butta Bomma',
        'Armaan Malik',
        'Ala Vaikunthapurramuloo',
      );

      mockRepo.mockResults = [song1, song2, song3];

      await viewModel.search('Ala Vaikunthapurramuloo');

      expect(viewModel.hasResults, isTrue);
      expect(viewModel.topResult, equals(song1));
      expect(viewModel.remainingResults.length, equals(2));
      expect(viewModel.remainingResults[0], equals(song2));
      expect(viewModel.remainingResults[1], equals(song3));
    });

    test('SearchFilter switching updates filtered results', () async {
      final song1 = createTestSong(
        '1',
        'Samajavaragamana',
        'Sid Sriram',
        'Ala Vaikunthapurramuloo',
      );
      final song2 = createTestSong(
        '2',
        'Kesariya',
        'Arijit Singh',
        'Brahmastra',
      );

      mockRepo.mockResults = [song1, song2];
      await viewModel.search('sid');

      viewModel.setFilter(SearchFilter.artists);
      expect(viewModel.selectedFilter, equals(SearchFilter.artists));
      expect(viewModel.filteredResults.length, equals(1));
      expect(viewModel.filteredResults.first.artist, contains('Sid Sriram'));

      viewModel.setFilter(SearchFilter.all);
      expect(viewModel.filteredResults.length, equals(2));
    });
  });
}
