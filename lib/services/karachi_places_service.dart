import 'dart:convert';
import 'package:flutter/services.dart';

class KarachiPlace {
  final String name;
  final double lat;
  final double lon;

  KarachiPlace({
    required this.name,
    required this.lat,
    required this.lon,
  });

  factory KarachiPlace.fromJson(Map<String, dynamic> json) {
    return KarachiPlace(
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

  /// Get formatted display name
  String get displayName {
    // Clean up the name if it contains encoding issues
    if (name.contains('Ø')) {
      // Try to decode or return a cleaned version
      return name.replaceAll(RegExp(r'[ØÚ©ÛŒÙ†]'), '').trim();
    }
    return name;
  }

  /// Get subtitle for display
  String get subtitle {
    return 'Karachi';
  }

  /// Convert to SearchResult format for compatibility
  Map<String, dynamic> toSearchResult() {
    return {
      'name': displayName,
      'subtitle': subtitle,
      'latitude': lat,
      'longitude': lon,
      'type': 'place',
      'source': 'karachi_places',
    };
  }
}

class KarachiPlacesService {
  static List<KarachiPlace> _places = [];
  static bool _isLoaded = false;
  static Map<String, List<KarachiPlace>> _searchCache = {};

  /// Load all places from JSON file
  static Future<void> loadPlaces() async {
    if (_isLoaded) return;

    try {
      print('📍 KarachiPlacesService: Loading places from places1.json...');
      final String jsonString = await rootBundle.loadString('assets/places1.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      
      _places = jsonList
          .map((json) => KarachiPlace.fromJson(json))
          .where((place) => 
              place.name.isNotEmpty && 
              place.lat != 0.0 && 
              place.lon != 0.0)
          .toList();
      
      _isLoaded = true;
      print('📍 KarachiPlacesService: Loaded ${_places.length} places');
    } catch (e) {
      print('❌ KarachiPlacesService: Error loading places: $e');
      _places = [];
    }
  }

  /// Search places with efficient filtering and caching
  static List<KarachiPlace> searchPlaces(String query) {
    if (!_isLoaded) {
      print('⚠️ KarachiPlacesService: Places not loaded yet');
      return [];
    }

    if (query.isEmpty) {
      return [];
    }

    final lowercaseQuery = query.toLowerCase().trim();
    
    // Check cache first
    if (_searchCache.containsKey(lowercaseQuery)) {
      return _searchCache[lowercaseQuery]!;
    }

    final results = <KarachiPlace>[];
    final queryWords = lowercaseQuery.split(' ');

    for (final place in _places) {
      final placeName = place.name.toLowerCase();
      final displayName = place.displayName.toLowerCase();
      
      // Check if all query words are found in the place name
      bool matches = true;
      for (final word in queryWords) {
        if (word.isNotEmpty && !placeName.contains(word) && !displayName.contains(word)) {
          matches = false;
          break;
        }
      }
      
      if (matches) {
        results.add(place);
      }
    }

    // Sort results by relevance
    results.sort((a, b) {
      final aName = a.name.toLowerCase();
      final bName = b.name.toLowerCase();
      
      // Exact matches first
      final aExact = aName == lowercaseQuery;
      final bExact = bName == lowercaseQuery;
      
      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;
      
      // Starts with query
      final aStartsWith = aName.startsWith(lowercaseQuery);
      final bStartsWith = bName.startsWith(lowercaseQuery);
      
      if (aStartsWith && !bStartsWith) return -1;
      if (!aStartsWith && bStartsWith) return 1;
      
      // Alphabetical order
      return aName.compareTo(bName);
    });

    // Cache the results
    _searchCache[lowercaseQuery] = results.take(20).toList();
    
    return results.take(20).toList();
  }

  /// Get popular places (first 6 places as example)
  static List<KarachiPlace> getPopularPlaces() {
    if (!_isLoaded) return [];
    return _places.take(6).toList();
  }

  /// Get places by category (if needed in future)
  static List<KarachiPlace> getPlacesByCategory(String category) {
    if (!_isLoaded) return [];
    
    final categoryLower = category.toLowerCase();
    return _places.where((place) {
      final name = place.name.toLowerCase();
      return name.contains(categoryLower);
    }).take(10).toList();
  }

  /// Clear search cache
  static void clearCache() {
    _searchCache.clear();
  }

  /// Get total number of places
  static int get totalPlaces => _places.length;

  /// Check if places are loaded
  static bool get isLoaded => _isLoaded;
} 