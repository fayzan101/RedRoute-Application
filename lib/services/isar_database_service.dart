import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/place_isar.dart';

class IsarDatabaseService {
  static Isar? _isar;
  static bool _isInitialized = false;

  /// Initialize Isar database
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      
      
      // Get the documents directory
      final dir = await getApplicationDocumentsDirectory();
      final path = dir.path;
      
      // Initialize Isar with the PlaceIsar schema
      _isar = await Isar.open(
        [PlaceIsarSchema],
        directory: path,
      );
      
      _isInitialized = true;
      
    } catch (e) {
      
      rethrow;
    }
  }

  /// Get the Isar instance
  static Isar get isar {
    if (_isar == null) {
      throw Exception('Isar database not initialized. Call initialize() first.');
    }
    return _isar!;
  }

  /// Load places from JSON file once and save to database permanently
  /// @deprecated Use DevelopmentDataImporter.importFromJson() instead
  static Future<void> loadPlacesFromJson() async {
   
    
    if (!_isInitialized) {
      await initialize();
    }

    try {
      
      
      // Check if data already exists in database
      final existingCount = await isar.placeIsars.count();
      if (existingCount > 0) {
        
        return;
      }

      
      
      // Load JSON from assets (only on first run)
      final String jsonString = await rootBundle.loadString('assets/places1.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      
      // Convert to PlaceIsar objects
      final places = jsonList
          .map((json) => PlaceIsar.fromJson(json))
          .where((place) => 
              place.name.isNotEmpty && 
              place.lat != 0.0 && 
              place.lon != 0.0)
          .toList();
      
      

      // Save to database permanently
      await isar.writeTxn(() async {
        await isar.placeIsars.putAll(places);
      });

      
    } catch (e) {
      
      rethrow;
    }
  }

  /// Search places in database
  static Future<List<PlaceIsar>> searchPlaces(String query) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (query.isEmpty) {
      return [];
    }

    try {
      final lowercaseQuery = query.toLowerCase().trim();
     
      
      // Get all places and filter in memory (more reliable for complex searches)
      final allPlaces = await isar.placeIsars.where().findAll();
      
      
      // Filter places that match the query
      final results = allPlaces.where((place) {
        final name = place.name.toLowerCase();
        final displayName = place.displayName.toLowerCase();
        
        // Check if query is contained in name or displayName
        return name.contains(lowercaseQuery) || displayName.contains(lowercaseQuery);
      }).toList();
      
      

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

      final finalResults = results.take(20).toList();
      
      
      return finalResults;
    } catch (e) {
      
      return [];
    }
  }

  /// Get popular places (first 6 places)
  static Future<List<PlaceIsar>> getPopularPlaces() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      return await isar.placeIsars
          .where()
          .limit(6)
          .findAll();
    } catch (e) {
      
      return [];
    }
  }

  /// Get total number of places
  static Future<int> getTotalPlaces() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      return await isar.placeIsars.count();
    } catch (e) {
      
      return 0;
    }
  }

  /// Clear all places from database
  static Future<void> clearAllPlaces() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await isar.writeTxn(() async {
        await isar.placeIsars.clear();
      });
      
    } catch (e) {
      
      rethrow;
    }
  }

  /// Close the database
  static Future<void> close() async {
    if (_isar != null) {
      await _isar!.close();
      _isar = null;
      _isInitialized = false;
      
    }
  }

  /// Check if database is initialized
  static bool get isInitialized => _isInitialized;

  /// Check if database has been populated with data
  static Future<bool> get hasData async {
    if (!_isInitialized) return false;
    try {
      final count = await isar.placeIsars.count();
      return count > 0;
    } catch (e) {
      return false;
    }
  }

  /// Get database statistics
  static Future<Map<String, dynamic>> getDatabaseStats() async {
    if (!_isInitialized) {
      return {
        'initialized': false,
        'totalPlaces': 0,
        'hasData': false,
      };
    }

    try {
      final totalPlaces = await isar.placeIsars.count();
      return {
        'initialized': true,
        'totalPlaces': totalPlaces,
        'hasData': totalPlaces > 0,
      };
    } catch (e) {
      return {
        'initialized': true,
        'totalPlaces': 0,
        'hasData': false,
        'error': e.toString(),
      };
    }
  }

  /// Debug method to check database contents (development only)
  static Future<List<Map<String, dynamic>>> debugGetAllPlaces() async {
    if (!kDebugMode) {
      return [];
    }

    if (!_isInitialized) {
      await initialize();
    }

    try {
      final places = await isar.placeIsars.where().findAll();
      return places.map((place) => {
        'id': place.id,
        'name': place.name,
        'displayName': place.displayName,
        'lat': place.lat,
        'lon': place.lon,
      }).toList();
    } catch (e) {
      
      return [];
    }
  }
} 