import 'package:isar/isar.dart';

part 'place_isar.g.dart';

@collection
class PlaceIsar {
  Id id = Isar.autoIncrement;

  @Index()
  String name;

  double lat;

  double lon;

  @Index()
  String displayName;

  PlaceIsar({
    required this.name,
    required this.lat,
    required this.lon,
  }) : displayName = _cleanDisplayName(name);

  static String _cleanDisplayName(String name) {
    // Clean up the name if it contains encoding issues
    if (name.contains('Ø')) {
      return name.replaceAll(RegExp(r'[ØÚ©ÛŒÙ†]'), '').trim();
    }
    return name;
  }

  factory PlaceIsar.fromJson(Map<String, dynamic> json) {
    return PlaceIsar(
      name: json['name'] ?? '',
      lat: (json['lat'] ?? 0.0).toDouble(),
      lon: (json['lon'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'lat': lat,
      'lon': lon,
    };
  }

  /// Get subtitle for display
  String get subtitle => 'Karachi';

  /// Convert to SearchResult format for compatibility
  Map<String, dynamic> toSearchResult() {
    return {
      'name': displayName,
      'subtitle': subtitle,
      'latitude': lat,
      'longitude': lon,
      'type': 'place',
      'source': 'isar_database',
    };
  }
} 