import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'secure_token_service.dart';
import '../utils/distance_calculator.dart';
import '../models/stop.dart';

class MapboxMatrixService {
  static const String _baseUrl = ApiConfig.mapboxBaseUrl;
  
  /// Get access token securely
  static Future<String> get _accessToken async {
    final token = await SecureTokenService.getToken();
    if (token != null && SecureTokenService.isValidToken(token)) {
      return token;
    }
    return ApiConfig.mapboxAccessToken;
  }

  /// Get matrix of distances and durations between multiple points using driving profile
  static Future<MapboxMatrixResponse?> getMatrix({
    required List<Map<String, double>> coordinates, // List of {lat, lng} coordinates
    String profile = 'driving',
  }) async {
    try {
      print('🗺️ MapboxMatrixService: Getting matrix for ${coordinates.length} coordinates');
      
      // Validate coordinates
      for (int i = 0; i < coordinates.length; i++) {
        final coord = coordinates[i];
        if (!_isValidCoordinate(coord['lat']!, coord['lng']!)) {
          print('❌ MapboxMatrixService: Invalid coordinate at index $i: ${coord['lat']}, ${coord['lng']}');
          return null;
        }
      }
      
      // Check rate limiting
      final isRateLimited = await SecureTokenService.isRateLimited();
      if (isRateLimited) {
        print('❌ MapboxMatrixService: Rate limited, skipping request');
        return null;
      }
      
      // Get access token
      final accessToken = await _accessToken;
      
      // Build coordinates string in longitude,latitude format
      final String coordinatesStr = coordinates
          .map((coord) => '${coord['lng']},${coord['lat']}')
          .join(';');
      
      // Build URL
      final Uri uri = Uri.parse('$_baseUrl/matrix/v1/mapbox/$profile/$coordinatesStr')
          .replace(queryParameters: {
        'access_token': accessToken,
        'annotations': 'distance,duration',
      });
      
      print('🌐 MapboxMatrixService: Matrix request URL: ${uri.toString().replaceAll(accessToken, '***')}');
      
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      
      print('📡 MapboxMatrixService: Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return MapboxMatrixResponse.fromJson(data);
      } else {
        print('❌ MapboxMatrixService: HTTP Error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ MapboxMatrixService: Error getting matrix: $e');
      return null;
    }
  }

  /// Find nearest stops using haversine formula and matrix API
  static Future<List<StopDistance>> findNearestStops({
    required double userLat,
    required double userLng,
    required List<Stop> allStops,
    int maxStops = 10,
  }) async {
    try {
      print('🎯 MapboxMatrixService: Finding $maxStops nearest stops using haversine + matrix API');
      print('📍 User location: ($userLat, $userLng)');
      print('📍 Total stops available: ${allStops.length}');
      
      // Step 1: Use haversine formula to find top 10 nearest stops
      final List<StopDistance> haversineResults = [];
      
      for (final stop in allStops) {
        final haversineDistance = DistanceCalculator.calculateDistance(
          userLat, userLng, stop.lat, stop.lng
        );
        
        haversineResults.add(StopDistance(
          stop: stop,
          haversineDistance: haversineDistance,
          drivingDistance: null,
          drivingDuration: null,
        ));
      }
      
      // Sort by haversine distance and take top maxStops
      haversineResults.sort((a, b) => a.haversineDistance.compareTo(b.haversineDistance));
      final topStops = haversineResults.take(maxStops).toList();
      
      print('📏 MapboxMatrixService: Top $maxStops stops by haversine distance:');
      for (int i = 0; i < topStops.length; i++) {
        final stop = topStops[i];
        print('   ${i + 1}. ${stop.stop.name}: ${DistanceCalculator.formatDistance(stop.haversineDistance)}');
      }
      
      // Step 2: Use matrix API to get driving distances for top stops
      final coordinates = [
        {'lat': userLat, 'lng': userLng}, // User location (source)
        ...topStops.map((stop) => {'lat': stop.stop.lat, 'lng': stop.stop.lng}), // Stop locations (destinations)
      ];
      
      final matrixResponse = await getMatrix(coordinates: coordinates);
      
      if (matrixResponse != null && matrixResponse.distances.isNotEmpty && matrixResponse.durations.isNotEmpty) {
        // Update driving distances and durations
        for (int i = 0; i < topStops.length; i++) {
          // Matrix response has user location as source (index 0) and stops as destinations (indices 1+)
          final distanceIndex = i + 1;
          if (distanceIndex < matrixResponse.distances[0].length) {
            topStops[i] = topStops[i].copyWith(
              drivingDistance: matrixResponse.distances[0][distanceIndex],
              drivingDuration: matrixResponse.durations[0][distanceIndex],
            );
          }
        }
        
        // Sort by driving distance (if available) or fall back to haversine
        topStops.sort((a, b) {
          if (a.drivingDistance != null && b.drivingDistance != null) {
            return a.drivingDistance!.compareTo(b.drivingDistance!);
          }
          return a.haversineDistance.compareTo(b.haversineDistance);
        });
        
        print('🚗 MapboxMatrixService: Top stops by driving distance:');
        for (int i = 0; i < topStops.length; i++) {
          final stop = topStops[i];
          final drivingInfo = stop.drivingDistance != null 
              ? '${DistanceCalculator.formatDistance(stop.drivingDistance!)} (${(stop.drivingDuration! / 60).round()}min)'
              : 'N/A';
          print('   ${i + 1}. ${stop.stop.name}: $drivingInfo');
        }
      } else {
        print('⚠️ MapboxMatrixService: Matrix API failed, using haversine distances only');
      }
      
      return topStops;
    } catch (e) {
      print('❌ MapboxMatrixService: Error finding nearest stops: $e');
      return [];
    }
  }

  /// Validate coordinate
  static bool _isValidCoordinate(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }
}

/// Response model for Mapbox Matrix API
class MapboxMatrixResponse {
  final List<List<double>> distances; // in meters
  final List<List<double>> durations; // in seconds
  final List<String> destinations;
  final List<String> sources;

  MapboxMatrixResponse({
    required this.distances,
    required this.durations,
    required this.destinations,
    required this.sources,
  });

  factory MapboxMatrixResponse.fromJson(Map<String, dynamic> json) {
    final List<List<double>> distances = [];
    final List<List<double>> durations = [];
    
    // Parse distances matrix
    if (json['distances'] != null) {
      for (final row in json['distances']) {
        distances.add(List<double>.from(row));
      }
    }
    
    // Parse durations matrix
    if (json['durations'] != null) {
      for (final row in json['durations']) {
        durations.add(List<double>.from(row));
      }
    }
    
    return MapboxMatrixResponse(
      distances: distances,
      durations: durations,
      destinations: List<String>.from(json['destinations'] ?? []),
      sources: List<String>.from(json['sources'] ?? []),
    );
  }
}

/// Model for stop with distance information
class StopDistance {
  final Stop stop;
  final double haversineDistance; // Straight-line distance in meters
  final double? drivingDistance; // Driving distance in meters (from matrix API)
  final double? drivingDuration; // Driving duration in seconds (from matrix API)

  StopDistance({
    required this.stop,
    required this.haversineDistance,
    this.drivingDistance,
    this.drivingDuration,
  });

  StopDistance copyWith({
    Stop? stop,
    double? haversineDistance,
    double? drivingDistance,
    double? drivingDuration,
  }) {
    return StopDistance(
      stop: stop ?? this.stop,
      haversineDistance: haversineDistance ?? this.haversineDistance,
      drivingDistance: drivingDistance ?? this.drivingDistance,
      drivingDuration: drivingDuration ?? this.drivingDuration,
    );
  }

  /// Get the best available distance (driving if available, otherwise haversine)
  double get bestDistance => drivingDistance ?? haversineDistance;
  
  /// Get the best available duration (driving if available, otherwise calculated from haversine)
  double get bestDuration => drivingDuration ?? (haversineDistance / 13.89); // Assume 50 km/h average speed
  
  /// Get formatted distance string
  String get formattedDistance => DistanceCalculator.formatDistance(bestDistance);
  
  /// Get formatted duration string
  String get formattedDuration {
    final minutes = (bestDuration / 60).round();
    if (minutes < 60) {
      return '${minutes}min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${remainingMinutes}min';
      }
    }
  }
} 