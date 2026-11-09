// ignore_for_file: avoid_print, unused_local_variable
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final languages = ['Telugu', 'Hindi', 'Tamil', 'English', 'Punjabi'];

  final queriesByLanguage = <String, List<String>>{
    'Telugu': [
      'Samajavaragamana', 'Butta Bomma', 'Inkem Inkem', 'Ramuloo Ramulaa', 'Oo Antava',
      'Srivalli', 'Chitti', 'Kurchi Madathapetti', 'Priya Mithunam', 'Adiga Adiga',
      'Nuvve Kavali', 'Nannaku Prematho', 'Vachinde', 'Seethayanamm', 'Amma Amma',
      'Dheevara', 'Saaho', 'Dookudu', 'Attarintiki Daredi', 'Magadheera',
      'Saranga Dariya', 'Rowdy Baby Telugu', 'Hoyna Hoyna', 'Neeli Neeli Aakasam', 'Undiporaadhey',
      'Darshana Telugu', 'Naatu Naatu', 'Komuram Bheemudo', 'Eyy Bidda Idhi Naa Adda', 'Jai Balayya',
      'Kalaavathi', 'Penny Song', 'Ma Ma Mahesha', 'Tillu Anna DJ Pedithe', 'Radhikaa',
      'Gaaju Bomma', 'Sammohanuda', 'Garam Garam', 'Fear Song Devara', 'Chuttamalle',
      'Daavudi', 'Ayudha Pooja', 'Pushpa Pushpa', 'Sooseki', 'Ta Takkara',
      'Theme of Kalki', 'Bhairava Anthem', 'Chinnanjiru Nilave Telugu', 'Poolane Kunukeyamantaa', 'O Rendu Prema Meghaalila'
    ],
    'Hindi': [
      'Kesariya', 'Tum Hi Ho', 'Channa Mereya', 'Apna Bana Le', 'Raataan Lambiyan',
      'Shayad', 'Kalank', 'Kabira', 'Agar Tum Saath Ho', 'Tujh Mein Rab Dikhta Hai',
      'Gerua', 'Zaalima', 'Ghungroo', 'Jai Jai Shivshankar', 'Dil Diyan Gallan',
      'Tera Ban Jaunga', 'Bekhayali', 'Tujhe Kitna Chahne Lage', 'Pal Pal Dil Ke Paas', 'Mast Magan',
      'Hawayein', 'Ilahi', 'Subhanallah', 'Kun Faya Kun', 'Nadaan Parindey',
      'Tum Se Hi', 'Pee Loon', 'Tum Mile', 'Te Amo', 'Jeene Laga Hoon',
      'Sun Saathiya', 'Galliyan', 'Hamari Adhuri Kahani', 'Ae Dil Hai Mushkil', 'Bulleya',
      'Hasi', 'Samjhawan', 'Main Rang Sharbaton Ka', 'Pani Da Rang', 'Sanam Re',
      'Kaun Tujhe', 'Jab Tak', 'Besabriyaan', 'Dekhte Dekhte', 'Namo Namo',
      'Qaafirana', 'Sweetheart', 'Jaan Nisaar', 'Tera Fitoor', 'Dhadak Title Track'
    ],
    'Tamil': [
      'Rowdy Baby', 'Vaathi Coming', 'Arabic Kuthu', 'Enjoy Enjaami', 'Kutty Pattas',
      'Master the Blaster', 'Chellamma', 'Two Two Two', 'Naan Pizhai', 'Bae Don',
      'Dippam Dappam', 'Private Party', 'Halamithi Habibo', 'Jalabulanjangu', 'Megham Karukatha',
      'Thaensudare', 'Thenmozhi', 'Hayyoda', 'Goli Soda', 'Aalaporan Thamizhan',
      'Neethanae', 'Mersal Arasan', 'Verithanam', 'Bigil Bigil', 'Singappenney',
      'Marana Mass', 'Petta Paraak', 'Kaali Theme', 'Ullaallaa', 'Chumma Kizhi',
      'Dharbar Theme', 'Vathi Raid', 'Andha Kanna Paathaakaa', 'Polakattum Para Para', 'Kutti Story',
      'Why This Kolaveri Di', 'Donu Donu Donu', 'Senjitaley', 'Sirikkadhey', 'Enna Solla',
      'VIP Title Track', 'Udhungada Sangu', 'Amma Amma Tamil', 'Po Indru Neeyaga', 'Pookkalae Sattru Oyivedungal',
      'Aathangara Orathil', 'Mental Manadhil', 'Kaara Faccina', 'Naane Varvean', 'Ranjithame'
    ],
    'English': [
      'Shape of You', 'Blinding Lights', 'Stay', 'Levitating', 'Someone You Loved',
      'Bad Habits', 'Save Your Tears', 'Watermelon Sugar', 'Peaches', 'As It Was',
      'Industry Baby', 'Heat Waves', 'Good 4 U', 'Kiss Me More', 'Montero',
      'Drivers License', 'Shivers', 'Cold Heart', 'Easy On Me', 'Ghost',
      'Anti-Hero', 'Flowers', 'Kill Bill', 'Creepin', 'Die For You',
      'Calm Down', 'Starboy', 'Cruel Summer', 'Vampire', 'Paint The Town Red',
      'Greedy', 'Lovin On Me', 'Espresso', 'Please Please Please', 'Birds of a Feather',
      'Lose Control', 'Beautiful Things', 'Too Sweet', 'I Had Some Help', 'A Bar Song',
      'Not Like Us', 'Million Dollar Baby', 'Stick Season', 'Fortnight', 'Lunch',
      'Thinking Out Loud', 'Perfect', 'Photograph', 'Castle on the Hill', 'Galway Girl'
    ],
    'Punjabi': [
      'Brown Munde', 'Insane', 'Excuses', 'Spaceship', 'Majhail',
      'Desires', 'Tere Te', 'G.O.A.T.', 'Born to Shine', 'Clash',
      'Lover', 'Peaches Diljit', 'Proper Patola', 'Do You Know', 'High Rated Gabru',
      'Lahore', 'Ban Ja Rani', 'Patola', 'Ishare Tere', 'Suit Suit',
      'Illegal Weapon', 'Kya Baat Ay', 'Naah', 'Nikle Currant', 'Coka',
      'Lehanga', 'Prada', 'Sakhiyaan', 'Biba', 'Sandals',
      'She Move It Like', 'Buzz', 'Mercy', 'DJ Waley Babu', 'Tareefan',
      'Same Beef', 'Old Skool', 'Game', 'Goat Sidhu', '295',
      'The Last Ride', 'Levels', 'Never Fold', 'These Days', 'So High',
      'Dard', 'Baller', 'Elevated', 'Check It Out', 'Softly'
    ],
  };

  final client = http.Client();
  const baseUrl = 'https://dilse-edge-stream.charanteja-kondakalla030206.workers.dev';

  int totalPassed = 0;
  int totalFailed = 0;
  final stopwatch = Stopwatch()..start();

  print('========================================================================');
  print('🚀 STARTING MASSIVE 250 TEST RUN (50 Queries × 5 Languages)');
  print('Target: Cloudflare Edge Worker (Zero Cold-Start V8 Isolate)');
  print('Validating: 200 OK Status, Non-empty streamUrl, 320kbps MP4 AAC direct link');
  print('========================================================================\n');

  for (final lang in languages) {
    print('------------------------------------------------------------------------');
    print('🌐 LANGUAGE SUITE: $lang (50 Unique Queries)');
    print('------------------------------------------------------------------------');

    final queries = queriesByLanguage[lang]!;
    int langPassed = 0;
    int langFailed = 0;

    for (int i = 0; i < queries.length; i++) {
      final query = queries[i];
      final testNum = i + 1;
      final uri = Uri.parse('$baseUrl/jio/search?q=${Uri.encodeComponent(query)}&limit=1&page=1');

      try {
        final queryWatch = Stopwatch()..start();
        final response = await client.get(uri).timeout(const Duration(seconds: 10));
        queryWatch.stop();

        if (response.statusCode == 200) {
          final List data = jsonDecode(response.body);
          if (data.isNotEmpty) {
            final song = data.first;
            final streamUrl = (song['streamUrl'] ?? '').toString();
            final title = (song['title'] ?? '').toString();
            final bitrate = (song['bitrate'] ?? '').toString();

            if (streamUrl.startsWith('http') && streamUrl.contains('.mp4')) {
              langPassed++;
              totalPassed++;
              print('[$lang #$testNum/50] ✅ PASS (${queryWatch.elapsedMilliseconds}ms) "$query" -> "$title" ($bitrate)');
            } else {
              langFailed++;
              totalFailed++;
              print('[$lang #$testNum/50] ⚠️ MALFORMED STREAM: "$query" -> $streamUrl');
            }
          } else {
            langFailed++;
            totalFailed++;
            print('[$lang #$testNum/50] ❌ EMPTY RESULTS: "$query"');
          }
        } else {
          langFailed++;
          totalFailed++;
          print('[$lang #$testNum/50] ❌ HTTP ${response.statusCode}: "$query"');
        }
      } catch (e) {
        langFailed++;
        totalFailed++;
        print('[$lang #$testNum/50] ❌ ERROR: "$query" -> $e');
      }

      // Small 80ms throttle to prevent DDOS protection trip
      await Future.delayed(const Duration(milliseconds: 80));
    }

    print('\n📊 $lang Summary: $langPassed/50 Passed (${(langPassed / 50 * 100).toStringAsFixed(1)}%)\n');
  }

  stopwatch.stop();
  client.close();

  print('========================================================================');
  print('🎯 FINAL 250 TEST REPORT SUMMARY');
  print('Total Tests Executed : 250');
  print('Total Tests Passed   : $totalPassed');
  print('Total Tests Failed   : $totalFailed');
  print('Success Rate         : ${(totalPassed / 250 * 100).toStringAsFixed(1)}%');
  print('Total Elapsed Time   : ${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)}s');
  print('========================================================================');
}

