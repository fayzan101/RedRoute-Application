import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'isar_database_service.dart';
import '../models/place_isar.dart';

/// Development-only service to import JSON data into Isar database
/// This should only be used during development and testing
class DevelopmentDataImporter {
  static const String _jsonAssetPath = 'assets/places1.json';
  
  /// Import data from JSON file into Isar database
  /// This method should only be called during development
  static Future<bool> importFromJson() async {
    // Only allow this in debug mode
    if (!kDebugMode) {
      print('⚠️ DevelopmentDataImporter: Import disabled in release mode');
      return false;
    }

    try {
      print('🔄 DevelopmentDataImporter: Starting JSON import...');
      
      // Check if database is initialized
      if (!IsarDatabaseService.isInitialized) {
        await IsarDatabaseService.initialize();
      }

      // Check if data already exists
      final existingCount = await IsarDatabaseService.getTotalPlaces();
      if (existingCount > 0) {
        
        return true;
      }

      
      
      // Load JSON from assets
      final String jsonString = await rootBundle.loadString(_jsonAssetPath);
      final List<dynamic> jsonList = json.decode(jsonString);
      
      
      
      // Convert to PlaceIsar objects
      final places = jsonList
          .map((json) => PlaceIsar.fromJson(json))
          .where((place) => 
              place.name.isNotEmpty && 
              place.lat != 0.0 && 
              place.lon != 0.0)
          .toList();
      
      

      // Save to database
      await IsarDatabaseService.isar.writeTxn(() async {
        await IsarDatabaseService.isar.placeIsars.putAll(places);
      });

      return true;
    } catch (e) {
    
      return false;
    }
  }

  /// Clear all data from Isar database (development only)
  static Future<bool> clearDatabase() async {
    if (!kDebugMode) {
      p
      return false;
    }

    try {
      print('🗑️ DevelopmentDataImporter: Clearing database...');
      await IsarDatabaseService.clearAllPlaces();
      
      return true;
    } catch (e) {
     
      return false;
    }
  }

  /// Get import status and database statistics
  static Future<Map<String, dynamic>> getImportStatus() async {
    if (!kDebugMode) {
      return {
        'developmentMode': false,
        'message': 'Import tools disabled in release mode',
      };
    }

    try {
      final stats = await IsarDatabaseService.getDatabaseStats();
      final hasData = await IsarDatabaseService.hasData;
      
      return {
        'developmentMode': true,
        'hasData': hasData,
        'totalPlaces': stats['totalPlaces'] ?? 0,
        'databaseInitialized': stats['initialized'] ?? false,
        'jsonAssetPath': _jsonAssetPath,
        'canImport': !hasData,
        'needsVerification': !hasData, // Only verify if no data exists
        'message': hasData 
          ? '✅ Database contains ${stats['totalPlaces']} places. Import not needed.'
          : '📥 Database is empty. Ready for import.',
      };
    } catch (e) {
      return {
        'developmentMode': true,
        'error': e.toString(),
        'message': 'Error checking import status',
      };
    }
  }

  /// Verify that the JSON file exists and is valid
  static Future<bool> verifyJsonFile() async {
    if (!kDebugMode) {
      return false;
    }

    try {
      final String jsonString = await rootBundle.loadString(_jsonAssetPath);
      final List<dynamic> jsonList = json.decode(jsonString);
      
      
      
      return jsonList.isNotEmpty;
    } catch (e) {
      
      return false;
    }
  }
} 