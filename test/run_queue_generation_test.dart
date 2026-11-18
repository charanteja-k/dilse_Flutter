// ignore_for_file: avoid_print, unused_import
import 'package:http/http.dart' as http;
import 'package:dilse/data/datasources/remote/cloudflare_edge_datasource.dart';
import 'package:dilse/data/models/song_model.dart';
import 'package:dilse/data/repositories/audio_repository_impl.dart';

void main() async {
  final languages = ['Telugu', 'Hindi', 'Tamil', 'English', 'Punjabi'];

  final seedQueries = <String, List<String>>{
    'Telugu': [
      'Samajavaragamana',
      'Butta Bomma',
      'Inkem Inkem',
      'Ramuloo Ramulaa',
      'Oo Antava',
      'Srivalli',
      'Chitti',
      'Kurchi Madathapetti',
      'Priya Mithunam',
      'Adiga Adiga',
    ],
    'Hindi': [
      'Kesariya',
      'Tum Hi Ho',
      'Channa Mereya',
      'Apna Bana Le',
      'Raataan Lambiyan',
      'Shayad',
      'Kalank',
      'Kabira',
      'Agar Tum Saath Ho',
      'Tujh Mein Rab Dikhta Hai',
    ],
    'Tamil': [
      'Rowdy Baby',
      'Vaathi Coming',
      'Arabic Kuthu',
      'Enjoy Enjaami',
      'Kutty Pattas',
      'Master the Blaster',
      'Chellamma',
      'Two Two Two',
      'Naan Pizhai',
      'Bae Don',
    ],
    'English': [
      'Shape of You',
      'Blinding Lights',
      'Stay',
      'Levitating',
      'Someone You Loved',
      'Bad Habits',
      'Save Your Tears',
      'Watermelon Sugar',
      'Peaches',
      'As It Was',
    ],
    'Punjabi': [
      'Brown Munde',
      'Insane',
      'Excuses',
      'Spaceship',
      'Majhail',
      'Desires',
      'Tere Te',
      'G.O.A.T.',
      'Born to Shine',
      'Clash',
    ],
  };

  final client = http.Client();
  final datasource = CloudflareEdgeDatasourceImpl(client: client);
  final repository = AudioRepositoryImpl(remoteDatasource: datasource);

  print(
    '========================================================================',
  );
  print('🚀 GOOGLE INNER-TUBE RADIO QUEUE GENERATION BENCHMARK');
  print('Target: 10 Seed Songs × 5 Languages = 50 Tests');
  print(
    'Pipeline: Seed -> Google Co-Listening Graph -> JioSaavn 320k Stream Resolution',
  );
  print(
    '========================================================================\n',
  );

  int totalPassed = 0;
  int totalFailed = 0;
  final stopwatch = Stopwatch()..start();

  for (final lang in languages) {
    print(
      '------------------------------------------------------------------------',
    );
    print('🌐 LANGUAGE: $lang (10 Seeds)');
    print(
      '------------------------------------------------------------------------',
    );

    final seeds = seedQueries[lang]!;
    int langPassed = 0;

    for (int i = 0; i < seeds.length; i++) {
      final seedQuery = seeds[i];
      final testWatch = Stopwatch()..start();

      try {
        // 1. Resolve initial seed song
        final searchResult = await repository.searchSongs(seedQuery, limit: 1);
        if (searchResult.isEmpty) {
          print(
            '[$lang #${i + 1}/10] ❌ Could not resolve initial seed: "$seedQuery"',
          );
          totalFailed++;
          continue;
        }

        final seedSong = searchResult.first;

        // 2. Generate algorithmic queue powered by Google InnerTube
        final queue = await repository.generateAlgorithmicQueue(
          seedSong: seedSong,
          limit: 15,
        );
        testWatch.stop();

        if (queue.length > 1) {
          langPassed++;
          totalPassed++;
          final nextTrack = queue[1];
          print(
            '[$lang #${i + 1}/10] ✅ PASS (${testWatch.elapsedMilliseconds}ms) Seed: "${seedSong.title}" -> Queue Size: ${queue.length} | Next: "${nextTrack.title}" (${nextTrack.bitrate})',
          );
        } else {
          print(
            '[$lang #${i + 1}/10] ⚠️ Queue only returned seed (No recommendations found): "$seedQuery"',
          );
          totalFailed++;
        }
      } catch (e) {
        print('[$lang #${i + 1}/10] ❌ ERROR: "$seedQuery" -> $e');
        totalFailed++;
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    print('\n📊 $lang Passed: $langPassed/10\n');
  }

  stopwatch.stop();
  client.close();

  print(
    '========================================================================',
  );
  print('🎯 FINAL QUEUE GENERATION REPORT');
  print('Total Seeds Tested : 50');
  print('Total Queues Formed: $totalPassed');
  print('Failed Queues      : $totalFailed');
  print('Success Rate       : ${(totalPassed / 50 * 100).toStringAsFixed(1)}%');
  print(
    'Total Duration     : ${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)}s',
  );
  print(
    '========================================================================',
  );
}
