import 'package:meta/meta.dart';

/// Pure immutable model describing a Home Vibe / Mood filter option.
@immutable
class MoodCategory {
  final String label;
  final String queryTemplate;
  final String description;

  const MoodCategory({
    required this.label,
    required this.queryTemplate,
    required this.description,
  });

  String resolveQuery(String primaryLanguage) {
    return queryTemplate.replaceAll('{lang}', primaryLanguage);
  }
}
