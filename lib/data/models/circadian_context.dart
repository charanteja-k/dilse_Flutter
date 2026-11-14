import 'package:meta/meta.dart';

/// Immutable model representing the time-of-day circadian context.
/// Strictly zero Flutter UI dependencies (AGENTS.md Invariant 3).
@immutable
class CircadianContext {
  final String title;
  final String subtitle;
  final String query;
  final String tag;
  final String emoji;

  const CircadianContext({
    required this.title,
    required this.subtitle,
    required this.query,
    required this.tag,
    required this.emoji,
  });

  /// Factory resolving current context based on the wall-clock hour.
  factory CircadianContext.fromHour(int hour, {String primaryLanguage = 'Telugu'}) {
    if (hour >= 5 && hour < 12) {
      return CircadianContext(
        title: 'Morning Melodies',
        subtitle: 'Soft acoustic & ambient vibes to start your day',
        query: '$primaryLanguage Morning Acoustic Hits',
        tag: 'MORNING',
        emoji: '🌅',
      );
    }
    if (hour >= 12 && hour < 17) {
      return CircadianContext(
        title: 'Afternoon Energy',
        subtitle: 'High-tempo beats and chartbusters to keep you grooving',
        query: '$primaryLanguage Trending Hits',
        tag: 'AFTERNOON',
        emoji: '⚡',
      );
    }
    if (hour >= 17 && hour < 22) {
      return CircadianContext(
        title: 'Evening Chill',
        subtitle: 'Trending relaxing tracks and chill evening vibes',
        query: '$primaryLanguage Soulful Hits',
        tag: 'EVENING',
        emoji: '🌆',
      );
    }
    return CircadianContext(
      title: 'Late Night Vibes',
      subtitle: 'Dreamy lo-fi and slowed melodies for quiet hours',
      query: '$primaryLanguage Late Night Lo-Fi',
      tag: 'NIGHT',
      emoji: '🌙',
    );
  }
}

