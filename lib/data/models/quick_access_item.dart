import 'package:meta/meta.dart';
import 'song_model.dart';

/// Immutable model representing a single tile in the 2x3 Quick Access Grid.
/// Zero Flutter UI dependencies (AGENTS.md Invariant 3).
@immutable
class QuickAccessItem {
  final String id;
  final String title;
  final String subtitle;
  final String iconKey;
  final String? imageUrl;
  final List<SongModel> songs;

  const QuickAccessItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconKey,
    this.imageUrl,
    this.songs = const [],
  });

  QuickAccessItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? iconKey,
    String? imageUrl,
    List<SongModel>? songs,
  }) {
    return QuickAccessItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      iconKey: iconKey ?? this.iconKey,
      imageUrl: imageUrl ?? this.imageUrl,
      songs: songs ?? this.songs,
    );
  }
}
