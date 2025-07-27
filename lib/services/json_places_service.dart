import 'dart:convert';
import 'package:flutter/services.dart';

class JsonPlace {
  final String name;
  final double lat;
  final double lon;
  final String? displayName;

  JsonPlace({
    required this.name,
    required this.lat,
    required this.lon,
    this.displayName,
  });

  factory JsonPlace.fromJson(Map<String, dynamic> json) {
    return JsonPlace(
      name: json['name'] ?? '',
      lat: (json['lat'] ?? 0.0).toDouble(),
      lon: (json['lon'] ?? 0.0).toDouble(),
      displayName: json['displayName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'lat': lat,
      'lon': lon,
      'displayName': displayName,
    };
  }

  /// Get formatted display name
  String get formattedDisplayName {
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!;
    }
    
    // Clean up the name if it contains encoding issues
    if (name.contains('Ø')) {
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
      'name': formattedDisplayName,
      'subtitle': subtitle,
      'latitude': lat,
      'longitude': lon,
      'type': 'place',
      'source': 'json_places',
    };
  }
}

class JsonPlacesService {
  static List<JsonPlace> _places = [];
  static bool _isLoaded = false;
  static Map<String, List<JsonPlace>> _searchCache = {};

  /// Load all places from JSON file
  static Future<void> loadPlaces() async {
    if (_isLoaded) return;

    try {
      print('📂 JsonPlacesService: Loading places from places1.json...');
      final String jsonString = await rootBundle.loadString('assets/places1.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      
      _places = jsonList
          .map((json) => JsonPlace.fromJson(json))
          .where((place) => 
              place.name.isNotEmpty && 
              place.lat != 0.0 && 
              place.lon != 0.0)
          .toList();
      
      _isLoaded = true;
      print('✅ JsonPlacesService: Loaded ${_places.length} places from JSON');
      
    } catch (e) {
      print('❌ JsonPlacesService: Error loading places: $e');
      _places = [];
    }
  }

  /// Search places with efficient filtering and caching
  static Future<List<JsonPlace>> searchPlaces(String query) async {
    if (!_isLoaded) {
      await loadPlaces();
    }

    if (query.isEmpty) {
      return [];
    }

    final lowercaseQuery = query.toLowerCase().trim();
    
    // Check cache first
    if (_searchCache.containsKey(lowercaseQuery)) {
      return _searchCache[lowercaseQuery]!;
    }

    final results = <JsonPlace>[];
    final queryWords = lowercaseQuery.split(' ');

    for (final place in _places) {
      final placeName = place.name.toLowerCase();
      final displayName = place.formattedDisplayName.toLowerCase();
      
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
    final finalResults = results.take(20).toList();
    _searchCache[lowercaseQuery] = finalResults;
    
    return finalResults;
  }

  /// Get popular places (first 6 places as example)
  static Future<List<JsonPlace>> getPopularPlaces() async {
    if (!_isLoaded) {
      await loadPlaces();
    }
    return _places.take(6).toList();
  }

  /// Get places by category (if needed in future)
  static Future<List<JsonPlace>> getPlacesByCategory(String category) async {
    if (!_isLoaded) {
      await loadPlaces();
    }
    
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
  static Future<int> get totalPlaces async {
    if (!_isLoaded) {
      await loadPlaces();
    }
    return _places.length;
  }

  /// Check if places are loaded
  static bool get isLoaded => _isLoaded;

  /// Extract coordinates for a specific location name
  static Future<Map<String, double>?> extractCoordinatesForLocation(String locationName) async {
    if (!_isLoaded) {
      await loadPlaces();
    }

    if (_places.isEmpty) {
      print('❌ JsonPlacesService: No places loaded');
      return null;
    }

    final lowercaseQuery = locationName.toLowerCase().trim();
    print('🔍 JsonPlacesService: Searching for coordinates for "$locationName"');

    // First try exact match
    for (final place in _places) {
      if (place.name.toLowerCase() == lowercaseQuery || 
          place.formattedDisplayName.toLowerCase() == lowercaseQuery) {
        print('✅ JsonPlacesService: Exact match found for "$locationName"');
        return {
          'lat': place.lat,
          'lng': place.lon,
        };
      }
    }

    // Then try partial match
    for (final place in _places) {
      if (place.name.toLowerCase().contains(lowercaseQuery) || 
          place.formattedDisplayName.toLowerCase().contains(lowercaseQuery)) {
        print('✅ JsonPlacesService: Partial match found for "$locationName"');
        return {
          'lat': place.lat,
          'lng': place.lon,
        };
      }
    }

    print('❌ JsonPlacesService: No coordinates found for "$locationName"');
    return null;
  }

  /// Get all places (for debugging or other purposes)
  static Future<List<JsonPlace>> getAllPlaces() async {
    if (!_isLoaded) {
      await loadPlaces();
    }
    return List.from(_places);
  }
} 