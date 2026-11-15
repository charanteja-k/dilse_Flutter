import 'package:flutter/material.dart';
import '../../../data/models/song_model.dart';

/// Represents a harmonious 3-color palette for ambient player backgrounds and glowing accents.
class AlbumPalette {
  final Color dominant;
  final Color vibrant;
  final Color darkVibrant;

  const AlbumPalette({
    required this.dominant,
    required this.vibrant,
    required this.darkVibrant,
  });
}

/// Instant deterministic & cached color deriver for album artwork backgrounds.
/// Ensures that the player background immediately adapts according to the album shown
/// with zero delay, no native palette plugin dependency, and no GPU blur overhead.
class AlbumColorDeriver {
  static final Map<String, AlbumPalette> _cache = {};

  /// Retrieves an adaptive palette for the given song.
  static AlbumPalette getPalette(SongModel? song) {
    if (song == null) {
      return const AlbumPalette(
        dominant: Color(0xFF141416),
        vibrant: Color(0xFFFFFFFF),
        darkVibrant: Color(0xFF101012),
      );
    }

    final id = song.id.isNotEmpty ? song.id : '${song.title}_${song.artist}';

    if (_cache.containsKey(id)) {
      return _cache[id]!;
    }

    // Instant deterministic color mapping based on song metadata.
    // Curated with high saturation and deep luminance for rich ambient aura behind the player.
    final hash = (song.title.hashCode ^ (song.artist.hashCode * 31) ^ (id.hashCode * 17)).abs();
    final double hue = (hash % 360).toDouble();

    final dominant = HSLColor.fromAHSL(1.0, hue, 0.65, 0.22).toColor();
    final vibrant = HSLColor.fromAHSL(1.0, hue, 0.85, 0.52).toColor();
    final darkVibrant = HSLColor.fromAHSL(
      1.0,
      (hue + 45) % 360,
      0.58,
      0.12,
    ).toColor();

    final palette = AlbumPalette(
      dominant: dominant,
      vibrant: vibrant,
      darkVibrant: darkVibrant,
    );
    _cache[id] = palette;
    return palette;
  }

  /// Clears the palette cache if needed.
  static void clearCache() {
    _cache.clear();
  }
}

