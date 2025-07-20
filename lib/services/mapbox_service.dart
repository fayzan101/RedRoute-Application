import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/distance_calculator.dart';
import 'secure_token_service.dart';

class MapboxService {
  static const String _baseUrl = ApiConfig.mapboxBaseUrl;
  
  /// Get access token securely
  static Future<String> get _accessToken async {
    final token = await SecureTokenService.getToken();
    if (token != null && SecureTokenService.isValidToken(token)) {
      return token;
    }
    return ApiConfig.mapboxAccessToken;
  }
  
  /// Search for places using Mapbox Geocoding API
  /// @deprecated Use IsarDatabaseService.searchPlaces() for local search instead
  static Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    print('⚠️ MapboxService: searchPlaces() is deprecated');
    print('⚠️ MapboxService: Use IsarDatabaseService.searchPlaces() for local search instead');
    return [];
  }

  /// Get address from coordinates (reverse geocoding)
  static Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      // Get access token securely
      final accessToken = await _accessToken;
      
      final Uri uri = Uri.parse('$_baseUrl${ApiConfig.mapboxGeocodingEndpoint}/$longitude,$latitude.json')
          .replace(queryParameters: {
        'access_token': accessToken,
        'types': 'poi,place,neighborhood,address',
        'limit': '1',
        'language': 'en',
      });

      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> features = data['features'] ?? [];
        
        if (features.isNotEmpty) {
          return features.first['place_name'] ?? null;
        }
      }
      return null;
    } catch (e) {
      print('Error getting address from coordinates: $e');
      return null;
    }
  }

  /// Get coordinates from address (forward geocoding)
  static Future<Map<String, double>?> getCoordinatesFromAddress(String address) async {
    try {
      // Get access token securely
      final accessToken = await _accessToken;
      
      final Uri uri = Uri.parse('$_baseUrl${ApiConfig.mapboxGeocodingEndpoint}/$address.json')
          .replace(queryParameters: {
        'access_token': accessToken,
        'bbox': ApiConfig.karachiBbox,
        'country': ApiConfig.pakistanCountryCode,
        'types': 'poi,place,neighborhood,address',
        'limit': '1',
        'language': 'en',
      });

      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> features = data['features'] ?? [];
        
        if (features.isNotEmpty) {
          final List<double> coordinates = List<double>.from(features.first['geometry']['coordinates'] ?? [0.0, 0.0]);
          return {
            'latitude': coordinates[1],
            'longitude': coordinates[0],
          };
        }
      }
      return null;
    } catch (e) {
      print('Error getting coordinates from address: $e');
      return null;
    }
  }

  /// Search for BRT stops specifically
  /// @deprecated Use DataService.searchStops() for BRT stop search instead
  static Future<List<Map<String, dynamic>>> searchBRTStops(String query) async {
    print('⚠️ MapboxService: searchBRTStops() is deprecated');
    print('⚠️ MapboxService: Use DataService.searchStops() for BRT stop search instead');
    return [];
  }

  /// Extract the best name from a Mapbox feature
  /// @deprecated No longer needed after removing place search functionality
  static String _extractName(Map<String, dynamic> feature) {
    print('⚠️ MapboxService: _extractName() is deprecated');
    return 'Unknown Location';
  }

  /// Get nearby places around a location
  /// @deprecated Use IsarDatabaseService for local place search instead
  static Future<List<Map<String, dynamic>>> getNearbyPlaces(
    double latitude, 
    double longitude, 
    {double radius = 1000}
  ) async {
    print('⚠️ MapboxService: getNearbyPlaces() is deprecated');
    print('⚠️ MapboxService: Use IsarDatabaseService for local place search instead');
    return [];
  }

  /// Get route directions between two points
  static Future<Map<String, dynamic>?> getRouteDirections({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    String profile = 'driving', // driving, walking, cycling
  }) async {
    try {
      // Validate coordinates are within reasonable bounds
      if (!_isValidCoordinate(startLat, startLng) || !_isValidCoordinate(endLat, endLng)) {
        print('❌ MapboxService: Invalid coordinates provided');
        print('   Start: ($startLat, $startLng)');
        print('   End: ($endLat, $endLng)');
        print('   Expected: lat -90 to 90, lng -180 to 180');
        return null;
      }
      
      // Check if coordinates are too close (same point)
      final distance = DistanceCalculator.calculateDistance(startLat, startLng, endLat, endLng);
      if (distance < 10) { // Less than 10 meters
        print('⚠️ MapboxService: Coordinates too close (${distance.toStringAsFixed(2)}m), skipping API call');
        return {
          'geometry': null,
          'duration': 0.0,
          'distance': distance,
          'steps': [],
          'summary': 'Same location',
        };
      }
      
      // Get access token securely
      final accessToken = await _accessToken;
      
      // Build the correct endpoint URL based on profile
      final String endpoint = '/directions/v5/mapbox/$profile';
      
      // Ensure coordinates are in the correct format (longitude,latitude)
      final String coordinates = '$startLng,$startLat;$endLng,$endLat';
      
      final Uri uri = Uri.parse('$_baseUrl$endpoint/$coordinates.json')
          .replace(queryParameters: {
        'access_token': accessToken,
        'geometries': 'geojson',
        'overview': 'full',
        'steps': 'true',
        'annotations': 'duration,distance,congestion,speed',
        'language': 'en',
        'continue_straight': 'true',
        'alternatives': 'false',
      });

      print('🌐 MapboxService: Getting route directions from ($startLat, $startLng) to ($endLat, $endLng)');
      print('🌐 MapboxService: Profile: $profile');
      print('🌐 MapboxService: Coordinates string: $coordinates');
      
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      
      print('📡 MapboxService: Route directions response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> routes = data['routes'] ?? [];
        
        if (routes.isNotEmpty) {
          final route = routes.first;
          final duration = route['duration'] ?? 0.0;
          final distance = route['distance'] ?? 0.0;
          
          print('✅ MapboxService: Route found - Distance: ${distance.toStringAsFixed(2)}m, Duration: ${duration.toStringAsFixed(2)}s');
          print('✅ MapboxService: Distance in km: ${(distance / 1000).toStringAsFixed(3)}km');
          
          // Validate distance makes sense
          final straightLineDistance = DistanceCalculator.calculateDistance(startLat, startLng, endLat, endLng);
          final ratio = distance / straightLineDistance;
          print('✅ MapboxService: Straight-line distance: ${straightLineDistance.toStringAsFixed(2)}m');
          print('✅ MapboxService: Route/straight-line ratio: ${ratio.toStringAsFixed(2)}');
          
          if (ratio < 0.5 || ratio > 3.0) {
            print('⚠️ MapboxService: WARNING - Route distance seems unusual (ratio: ${ratio.toStringAsFixed(2)})');
          }
          
          return {
            'geometry': route['geometry'],
            'duration': duration,
            'distance': distance,
            'steps': route['legs']?.first?['steps'] ?? [],
            'summary': route['legs']?.first?['summary'] ?? '',
          };
        } else {
          print('⚠️ MapboxService: No routes found in response');
        }
      } else if (response.statusCode == 422) {
        print('❌ MapboxService: Invalid request parameters for route directions');
        print('   Response: ${response.body}');
        return null;
      } else {
        print('❌ MapboxService: HTTP Error ${response.statusCode} for route directions: ${response.body}');
        return null;
      }
      return null;
    } catch (e) {
      print('Error getting route directions: $e');
      return null;
    }
  }

  /// Get walking directions to a bus stop
  static Future<Map<String, dynamic>?> getWalkingDirectionsToStop({
    required double userLat,
    required double userLng,
    required double stopLat,
    required double stopLng,
  }) async {
    return await getRouteDirections(
      startLat: userLat,
      startLng: userLng,
      endLat: stopLat,
      endLng: stopLng,
      profile: 'walking',
    );
  }

  /// Get static map image URL for a route
  static Future<String> getStaticMapUrl({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    List<Map<String, double>>? waypoints,
    int width = 400,
    int height = 300,
    double zoom = 12,
  }) async {
    // Get access token securely
    final accessToken = await _accessToken;
    
    final List<String> coordinates = [];
    
    // Add start point
    coordinates.add('$startLng,$startLat');
    
    // Add waypoints if provided
    if (waypoints != null) {
      for (final waypoint in waypoints) {
        coordinates.add('${waypoint['longitude']},${waypoint['latitude']}');
      }
    }
    
    // Add end point
    coordinates.add('$endLng,$endLat');
    
    final String path = coordinates.join(';');
    
    return '$_baseUrl/styles/v1/mapbox/streets-v11/static/path-5+E53E3E-1($path)/$startLng,$startLat,$zoom/$width x $height?access_token=$accessToken&padding=50';
  }

  /// Get static map URL for bus route with stops
  static Future<String> getBusRouteMapUrl({
    required List<Map<String, double>> stops,
    int width = 400,
    int height = 300,
  }) async {
    if (stops.isEmpty) return '';
    
    // Get access token securely
    final accessToken = await _accessToken;
    
    final List<String> coordinates = stops.map((stop) => '${stop['longitude']},${stop['latitude']}').toList();
    final String path = coordinates.join(';');
    
    // Calculate center and zoom
    double minLat = stops.map((s) => s['latitude']!).reduce((a, b) => a < b ? a : b);
    double maxLat = stops.map((s) => s['latitude']!).reduce((a, b) => a > b ? a : b);
    double minLng = stops.map((s) => s['longitude']!).reduce((a, b) => a < b ? a : b);
    double maxLng = stops.map((s) => s['longitude']!).reduce((a, b) => a > b ? a : b);
    
    final double centerLat = (minLat + maxLat) / 2;
    final double centerLng = (minLng + maxLng) / 2;
    
    // Calculate appropriate zoom level
    final double latDiff = maxLat - minLat;
    final double lngDiff = maxLng - minLng;
    final double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    
    double zoom = 12;
    if (maxDiff > 0.1) zoom = 10;
    if (maxDiff > 0.05) zoom = 11;
    if (maxDiff > 0.02) zoom = 12;
    if (maxDiff > 0.01) zoom = 13;
    if (maxDiff > 0.005) zoom = 14;
    
    return '$_baseUrl/styles/v1/mapbox/streets-v11/static/path-5+E53E3E-1($path)/$centerLng,$centerLat,$zoom/$width x $height?access_token=$accessToken&padding=50';
  }

  /// Get detailed journey information including multiple transport modes
  static Future<Map<String, dynamic>> getJourneyDetails({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required double busStopLat,
    required double busStopLng,
    required double destinationStopLat,
    required double destinationStopLng,
  }) async {
    try {
      // Get walking directions to bus stop
      final walkingToStop = await getWalkingDirectionsToStop(
        userLat: startLat,
        userLng: startLng,
        stopLat: busStopLat,
        stopLng: busStopLng,
      );
      
      // Get walking directions from bus stop to destination
      final walkingFromStop = await getWalkingDirectionsToStop(
        userLat: destinationStopLat,
        userLng: destinationStopLng,
        stopLat: endLat,
        stopLng: endLng,
      );
      
      // Get driving directions (for Bykea/Careem comparison)
      final drivingDirections = await getRouteDirections(
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
        profile: 'driving',
      );
      
      // Get cycling directions (for Bykea comparison)
      final cyclingDirections = await getRouteDirections(
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
        profile: 'cycling',
      );
      
      return {
        'walkingToStop': walkingToStop,
        'walkingFromStop': walkingFromStop,
        'driving': drivingDirections,
        'cycling': cyclingDirections,
        'totalWalkingDistance': (walkingToStop?['distance'] ?? 0) + (walkingFromStop?['distance'] ?? 0),
        'totalWalkingDuration': (walkingToStop?['duration'] ?? 0) + (walkingFromStop?['duration'] ?? 0),
        'drivingDistance': drivingDirections?['distance'] ?? 0,
        'drivingDuration': drivingDirections?['duration'] ?? 0,
        'cyclingDistance': cyclingDirections?['distance'] ?? 0,
        'cyclingDuration': cyclingDirections?['duration'] ?? 0,
      };
    } catch (e) {
      print('Error getting journey details: $e');
      return {};
    }
  }

  /// Get nearby transport options (bus stops, taxi stands, etc.)
  /// @deprecated Use DataService for BRT stop search instead
  static Future<List<Map<String, dynamic>>> getNearbyTransportOptions({
    required double latitude,
    required double longitude,
    double radius = 1000,
  }) async {
    print('⚠️ MapboxService: getNearbyTransportOptions() is deprecated');
    print('⚠️ MapboxService: Use DataService for BRT stop search instead');
    return [];
  }

  /// Get traffic information for a route
  /// @deprecated Traffic information functionality removed
  static Future<Map<String, dynamic>?> getTrafficInfo({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    print('⚠️ MapboxService: getTrafficInfo() is deprecated');
    print('⚠️ MapboxService: Traffic information functionality has been removed');
    return null;
  }

  /// Calculate traffic level based on duration
  /// @deprecated Traffic information functionality removed
  static String _calculateTrafficLevel(double duration) {
    print('⚠️ MapboxService: _calculateTrafficLevel() is deprecated');
    return 'Unknown';
  }
  
  /// Format duration in minutes
  /// @deprecated Traffic information functionality removed
  static String _formatDuration(double seconds) {
    print('⚠️ MapboxService: _formatDuration() is deprecated');
    return 'Unknown';
  }
  
  /// Format distance in km
  /// @deprecated Traffic information functionality removed
  static String _formatDistance(double meters) {
    print('⚠️ MapboxService: _formatDistance() is deprecated');
    return 'Unknown';
  }

  /// Test method to check if Mapbox service is working
  static Future<bool> testConnection() async {
    try {
      print('🧪 MapboxService: Testing connection...');
      
      // Get access token securely
      final accessToken = await _accessToken;
      
      final Uri uri = Uri.parse('$_baseUrl/geocoding/v5/mapbox.places/Karachi.json')
          .replace(queryParameters: {
        'access_token': accessToken,
        'limit': '1',
      });

      final response = await http.get(uri);
      
      print('🧪 MapboxService: Test response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] ?? [];
        print('🧪 MapboxService: Test successful - found ${features.length} features');
        return true;
      } else {
        print('🧪 MapboxService: Test failed - HTTP ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      print('🧪 MapboxService: Test failed with error: $e');
      return false;
    }
  }
  
  /// Test distance calculation with known coordinates
  static Future<void> testDistanceCalculation() async {
    try {
      print('🧪 MapboxService: Testing distance calculation...');
      
      // Test with Karachi center to Fast University (known distance ~25km)
      final karachiCenterLat = 24.8607;
      final karachiCenterLng = 67.0011;
      final fastUniLat = 24.8571541;
      final fastUniLng = 67.2645918;
      
      print('🧪 MapboxService: Testing route from Karachi center to Fast University');
      print('   Start: ($karachiCenterLat, $karachiCenterLng)');
      print('   End: ($fastUniLat, $fastUniLng)');
      
      // Calculate straight-line distance
      final straightLineDistance = DistanceCalculator.calculateDistance(
        karachiCenterLat, karachiCenterLng, fastUniLat, fastUniLng
      );
      print('🧪 MapboxService: Straight-line distance: ${(straightLineDistance / 1000).toStringAsFixed(2)}km');
      
      // Get Mapbox route distance
      final routeInfo = await getRouteDirections(
        startLat: karachiCenterLat,
        startLng: karachiCenterLng,
        endLat: fastUniLat,
        endLng: fastUniLng,
        profile: 'driving',
      );
      
      if (routeInfo != null) {
        final mapboxDistance = routeInfo['distance'] as double;
        final ratio = mapboxDistance / straightLineDistance;
        
        print('🧪 MapboxService: Mapbox route distance: ${(mapboxDistance / 1000).toStringAsFixed(2)}km');
        print('🧪 MapboxService: Route/straight-line ratio: ${ratio.toStringAsFixed(2)}');
        
        if (ratio >= 1.0 && ratio <= 2.0) {
          print('✅ MapboxService: Distance calculation looks reasonable');
        } else {
          print('⚠️ MapboxService: Distance calculation seems unusual');
        }
      } else {
        print('❌ MapboxService: Failed to get route from Mapbox');
      }
      
    } catch (e) {
      print('❌ MapboxService: Error testing distance calculation: $e');
    }
  }
  
  /// Validate if coordinates are within valid geographic bounds
  static bool _isValidCoordinate(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }
  
  /// Validate if coordinates are within Karachi area
  static bool _isInKarachiArea(double lat, double lng) {
    // Karachi bounding box (roughly)
    const double karachiMinLat = 24.7;
    const double karachiMaxLat = 25.2;
    const double karachiMinLng = 66.8;
    const double karachiMaxLng = 67.4;
    
    return lat >= karachiMinLat && lat <= karachiMaxLat &&
           lng >= karachiMinLng && lng <= karachiMaxLng;
  }
} 