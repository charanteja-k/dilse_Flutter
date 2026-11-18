import 'package:meta/meta.dart';

/// Pure immutable domain model representing a song.
/// Zero Flutter UI dependencies (strictly adheres to AGENTS.md Invariant 3).
@immutable
class SongModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String thumbnailUrl;
  final String streamUrl;
  final Duration duration;
  final String source;
  final String bitrate;

  const SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.thumbnailUrl,
    required this.streamUrl,
    required this.duration,
    this.source = 'jiosaavn',
    this.bitrate = '320kbps',
  });

  String get artworkUrl => thumbnailUrl;
  int get durationMs => duration.inMilliseconds;

  factory SongModel.fromJson(Map<String, dynamic> json) {
    Duration parsedDuration = Duration.zero;
    final rawDuration = json['duration'] ?? json['durationSeconds'];
    if (rawDuration is num) {
      parsedDuration = Duration(seconds: rawDuration.toInt());
    } else if (rawDuration is String) {
      final parsed = int.tryParse(rawDuration);
      if (parsed != null) {
        parsedDuration = Duration(seconds: parsed);
      } else if (rawDuration.contains(':')) {
        final parts = rawDuration.trim().split(':');
        if (parts.length == 2) {
          final m = int.tryParse(parts[0]) ?? 0;
          final s = int.tryParse(parts[1]) ?? 0;
          parsedDuration = Duration(minutes: m, seconds: s);
        } else if (parts.length == 3) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final s = int.tryParse(parts[2]) ?? 0;
          parsedDuration = Duration(hours: h, minutes: m, seconds: s);
        }
      }
    }

    return SongModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Unknown Title').toString(),
      artist: (json['author'] ?? json['artist'] ?? 'Unknown Artist').toString(),
      album: (json['album'] ?? 'DilSe').toString(),
      thumbnailUrl:
          (json['thumbnail'] ?? json['thumbnailUrl'] ?? json['artwork'] ?? '')
              .toString(),
      streamUrl: (json['streamUrl'] ?? '').toString(),
      duration: parsedDuration,
      source: (json['source'] ?? 'jiosaavn').toString(),
      bitrate: (json['bitrate'] ?? '320kbps').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'thumbnailUrl': thumbnailUrl,
      'streamUrl': streamUrl,
      'duration': duration.inSeconds,
      'source': source,
      'bitrate': bitrate,
    };
  }

  SongModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? thumbnailUrl,
    String? streamUrl,
    Duration? duration,
    String? source,
    String? bitrate,
  }) {
    return SongModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      duration: duration ?? this.duration,
      source: source ?? this.source,
      bitrate: bitrate ?? this.bitrate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SongModel(id: $id, title: $title, artist: $artist, streamUrl: $streamUrl)';
}
