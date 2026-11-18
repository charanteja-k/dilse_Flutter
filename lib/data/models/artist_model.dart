import 'package:meta/meta.dart';

/// Pure immutable domain model representing an Artist.
/// Zero Flutter UI dependencies (strictly adheres to AGENTS.md Invariant 3).
@immutable
class ArtistModel {
  final String id;
  final String name;
  final String role;
  final String thumbnailUrl;

  const ArtistModel({
    required this.id,
    required this.name,
    required this.role,
    required this.thumbnailUrl,
  });

  factory ArtistModel.fromJson(Map<String, dynamic> json) {
    String cleanArt = (json['image'] ?? '').toString();
    if (cleanArt.contains('150x150')) {
      cleanArt = cleanArt.replaceAll('150x150', '500x500');
    } else if (cleanArt.contains('50x50')) {
      cleanArt = cleanArt.replaceAll('50x50', '500x500');
    }

    return ArtistModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? 'Unknown Artist').toString(),
      role: (json['role'] ?? json['description'] ?? 'Artist').toString(),
      thumbnailUrl: cleanArt,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'role': role, 'thumbnailUrl': thumbnailUrl};
  }
}
