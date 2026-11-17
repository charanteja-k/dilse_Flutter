import 'package:meta/meta.dart';

/// Pure immutable domain model representing an Album.
/// Zero Flutter UI dependencies (strictly adheres to AGENTS.md Invariant 3).
@immutable
class AlbumModel {
  final String id;
  final String title;
  final String subtitle;
  final String artist;
  final String year;
  final String language;
  final String thumbnailUrl;
  final int songCount;

  const AlbumModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.artist,
    required this.year,
    required this.language,
    required this.thumbnailUrl,
    required this.songCount,
  });

  factory AlbumModel.fromJson(Map<String, dynamic> json) {
    final moreInfo = json['more_info'] is Map ? json['more_info'] as Map : {};
    final rawCount = moreInfo['song_count'] ?? json['song_count'] ?? '0';
    final count = int.tryParse(rawCount.toString()) ?? 0;

    String cleanArt = (json['image'] ?? '').toString();
    if (cleanArt.contains('150x150')) {
      cleanArt = cleanArt.replaceAll('150x150', '500x500');
    } else if (cleanArt.contains('50x50')) {
      cleanArt = cleanArt.replaceAll('50x50', '500x500');
    }

    return AlbumModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? 'Unknown Album').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      artist: (moreInfo['music'] ?? json['artist'] ?? json['subtitle'] ?? 'DilSe Artist').toString(),
      year: (json['year'] ?? moreInfo['year'] ?? '').toString(),
      language: (json['language'] ?? moreInfo['language'] ?? '').toString(),
      thumbnailUrl: cleanArt,
      songCount: count,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'artist': artist,
      'year': year,
      'language': language,
      'thumbnailUrl': thumbnailUrl,
      'songCount': songCount,
    };
  }
}
