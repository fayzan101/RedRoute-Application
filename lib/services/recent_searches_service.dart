import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecentSearch {
  final String query;
  final String name;
  final String subtitle;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  RecentSearch({
    required this.query,
    required this.name,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'name': name,
      'subtitle': subtitle,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory RecentSearch.fromJson(Map<String, dynamic> json) {
    return RecentSearch(
      query: json['query'] ?? '',
      name: json['name'] ?? '',
      subtitle: json['subtitle'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
    );
  }
}

class RecentSearchesService {
  static const String _storageKey = 'recent_searches';
  static const int _maxSearches = 10;

  Future<List<RecentSearch>> getRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? searchesJson = prefs.getString(_storageKey);
      
      if (searchesJson == null) return [];
      
      final List<dynamic> searchesList = json.decode(searchesJson);
      return searchesList
          .map((json) => RecentSearch.fromJson(json))
          .toList();
    } catch (e) {
      print('Error loading recent searches: $e');
      return [];
    }
  }

  Future<void> addRecentSearch(RecentSearch search) async {
    try {
      final searches = await getRecentSearches();
      
      // Remove duplicate if exists
      searches.removeWhere((s) => s.query.toLowerCase() == search.query.toLowerCase());
      
      // Add new search at the beginning
      searches.insert(0, search);
      
      // Keep only the most recent searches
      if (searches.length > _maxSearches) {
        searches.removeRange(_maxSearches, searches.length);
      }
      
      // Save to storage
      final prefs = await SharedPreferences.getInstance();
      final searchesJson = json.encode(searches.map((s) => s.toJson()).toList());
      await prefs.setString(_storageKey, searchesJson);
    } catch (e) {
      print('Error saving recent search: $e');
    }
  }

  Future<void> clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      print('Error clearing recent searches: $e');
    }
  }
} 