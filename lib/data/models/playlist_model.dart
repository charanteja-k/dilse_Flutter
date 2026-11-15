import 'package:meta/meta.dart';
import 'song_model.dart';

/// Immutable model representing a user-created or imported playlist.
/// Adheres strictly to AGENTS.md:
/// - Invariant 3: Model is pure data, zero Flutter UI dependencies.
@immutable
class PlaylistModel {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final List<SongModel> songs;
  final DateTime createdAt;

  const PlaylistModel({
    required this.id,
    required this.title,
    this.description = '',
    this.thumbnailUrl = '',
    this.songs = const [],
    required this.createdAt,
  });

  int get songCount => songs.length;

  Duration get totalDuration =>
      songs.fold(Duration.zero, (prev, s) => prev + s.duration);

  PlaylistModel copyWith({
    String? id,
    String? title,
    String? description,
    String? thumbnailUrl,
    List<SongModel>? songs,
    DateTime? createdAt,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      songs: songs ?? this.songs,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'songs': songs.map((s) => s.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PlaylistModel.fromJson(Map<String, dynamic> json) {
    return PlaylistModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      songs: (json['songs'] as List<dynamic>?)
              ?.map((e) => SongModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

