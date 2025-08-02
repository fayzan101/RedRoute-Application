import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/distance_calculator.dart';
import 'secure_token_service.dart';

/// Route types supported by Mapbox Directions API
enum MapboxRouteType {
  driving,        // Standard driving route
  walking,        // Walking route
  cycling,        // Cycling route
  drivingTraffic, // Real-time traffic driving route
}

class MapboxService {
  static const String _baseUrl = ApiConfig.mapboxBaseUrl;
  static String? _cachedToken;
  static bool _isFirstRequest = true;
  

  
  /// Get access token securely with caching
  static Future<String> get _accessToken async {
    if (_cachedToken != null) {
      return _cachedToken!;
    }
    
    final token = await SecureTokenService.getToken();
    if (token != null && SecureTokenService.isValidToken(token)) {
      _cachedToken = token;
      return token;
    }
    
    _cachedToken = ApiConfig.mapboxAccessToken;
    return _cachedToken!;
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

  /// Get directions between two points with enhanced error handling and rate limiting
  static Future<MapboxDirectionsResponse?> getDirections({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    MapboxRouteType routeType = MapboxRouteType.drivingTraffic,
    List<double>? waypoints,
    bool alternatives = false,
    bool steps = true,
    bool annotations = true,
    String overview = 'full',
    bool continueStraight = true,
  }) async {
    int retryCount = 0;
    const maxRetries = 3; // Increased retries for better reliability
    
    while (retryCount < maxRetries) {
      try {
        print('🗺️ MapboxService: Getting directions from ($startLat, $startLng) to ($endLat, $endLng) [Attempt ${retryCount + 1}/$maxRetries]');
        
        // Handle first request specially with better initialization
        if (_isFirstRequest) {
          print('🔄 MapboxService: First request - initializing service...');
          
          // Clear rate limit and pre-warm token cache
          await SecureTokenService.clearRateLimit();
          await _accessToken;
          
          // Test connection to ensure everything is working
          try {
            final testResult = await testConnection();
            if (!testResult) {
              print('⚠️ MapboxService: Connection test failed, but continuing...');
            }
          } catch (e) {
            print('⚠️ MapboxService: Connection test error: $e, but continuing...');
          }
          
          _isFirstRequest = false;
        }
        
        // Validate coordinates
        if (!_isValidCoordinate(startLat, startLng) || !_isValidCoordinate(endLat, endLng)) {
          print('❌ MapboxService: Invalid coordinates provided');
          return null;
        }
        
        // Check rate limiting
        final isRateLimited = await SecureTokenService.isRateLimited();
        if (isRateLimited) {
          print('❌ MapboxService: Rate limited, skipping request');
          return null;
        }
        
        // Reduced delay for better responsiveness
        if (retryCount > 0) {
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
        
        final accessToken = await _accessToken;
        
        // Build coordinates string
        String coordinates = '$startLng,$startLat';
        if (waypoints != null && waypoints.isNotEmpty) {
          for (int i = 0; i < waypoints.length; i += 2) {
            if (i + 1 < waypoints.length) {
              coordinates += ';${waypoints[i]},${waypoints[i + 1]}';
            }
          }
        }
        coordinates += ';$endLng,$endLat';
        
        // Validate route type
        String routeTypeStr = _validateRouteType(routeType);
        
        // Build query parameters
        final Map<String, String> queryParams = {
          'access_token': accessToken,
          'geometries': 'geojson',
          'overview': overview,
          'steps': steps.toString(),
          'continue_straight': continueStraight.toString(),
          'alternatives': alternatives.toString(),
          'language': 'en',
          'annotations': 'duration,distance,congestion,speed',
        };
        
        final Uri uri = Uri.parse('$_baseUrl/directions/v5/mapbox/$routeTypeStr/$coordinates.json')
            .replace(queryParameters: queryParams);
        
        final response = await http.get(uri).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (!_isValidDirectionsResponse(data)) {
          print('❌ MapboxService: Invalid response structure');
          return null;
        }
        
        final directionsResponse = MapboxDirectionsResponse.fromJson(data);
        
        // Log route information for debugging
        if (directionsResponse.routes.isNotEmpty) {
          final route = directionsResponse.routes.first;
          print('📏 MapboxService: Route distance: ${route.distance}m, duration: ${route.duration}s');
          
                     // Validate distance ratio but don't modify the route object
           final straightLineDistance = DistanceCalculator.calculateDistance(startLat, startLng, endLat, endLng);
           final ratio = route.distance / straightLineDistance;
           
           if (ratio < 0.3 || ratio > 5.0) {
             print('⚠️ MapboxService: WARNING - Route distance seems unusual (ratio: ${ratio.toStringAsFixed(2)})');
             if (ratio < 0.1 || ratio > 10.0) {
               print('🔄 MapboxService: Distance ratio indicates potential issue: ${ratio.toStringAsFixed(2)}');
             }
           }
        }
        
        return directionsResponse;
      } else if (response.statusCode == 422) {
        print('❌ MapboxService: Invalid request parameters');
        return null;
      } else {
        print('❌ MapboxService: HTTP Error ${response.statusCode}: ${response.body}');
        // Retry on server errors (5xx) but not on client errors (4xx)
        if (response.statusCode >= 500 && retryCount < maxRetries - 1) {
          retryCount++;
          print('🔄 MapboxService: Retrying due to server error...');
          continue;
        }
        return null;
      }
    } catch (e) {
      print('❌ MapboxService: Error getting directions: $e');
      if (retryCount < maxRetries - 1) {
        retryCount++;
        print('🔄 MapboxService: Retrying due to exception...');
        continue;
      }
      return null;
    }
    }
    
    print('❌ MapboxService: Failed after $maxRetries attempts');
    return null;
  }

  /// Get route information (simplified version of getDirections) with improved distance validation
  static Future<MapboxRouteInfo?> getRouteInfo({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    MapboxRouteType routeType = MapboxRouteType.drivingTraffic,
  }) async {
    try {
      final response = await getDirections(
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
        routeType: routeType,
        alternatives: false,
        steps: true,
        annotations: true,
      );
      
      if (response != null && response.routes.isNotEmpty) {
        final route = response.routes.first;
        
        // Additional distance validation and correction
        double validatedDistance = route.distance;
        final straightLineDistance = DistanceCalculator.calculateDistance(startLat, startLng, endLat, endLng);
        final ratio = route.distance / straightLineDistance;
        
        // If distance is clearly wrong, use a reasonable estimate
        if (ratio < 0.1 || ratio > 10.0) {
          validatedDistance = straightLineDistance * 1.2; // 20% buffer for road network
          print('🔄 MapboxService: Corrected route distance from ${route.distance}m to ${validatedDistance.round()}m (ratio: ${ratio.toStringAsFixed(2)})');
        } else if (ratio < 0.3 || ratio > 5.0) {
          print('⚠️ MapboxService: Route distance ratio unusual but acceptable: ${ratio.toStringAsFixed(2)}');
        }
        
        return MapboxRouteInfo(
          distance: validatedDistance,
          duration: route.duration,
          routeType: routeType,
          geometry: route.geometry,
        );
      }
      
      return null;
    } catch (e) {
      print('❌ MapboxService: Error getting route info: $e');
      return null;
    }
  }

  /// Get walking directions
  static Future<MapboxRouteInfo?> getWalkingRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    return await getRouteInfo(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
      routeType: MapboxRouteType.walking,
    );
  }

  /// Get driving directions with real-time traffic
  static Future<MapboxRouteInfo?> getDrivingRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    return await getRouteInfo(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
      routeType: MapboxRouteType.drivingTraffic,
    );
  }

  /// Get cycling directions
  static Future<MapboxRouteInfo?> getCyclingRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    return await getRouteInfo(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
      routeType: MapboxRouteType.cycling,
    );
  }

  /// Get walking directions to a bus stop (legacy method for compatibility)
  static Future<Map<String, dynamic>?> getWalkingDirectionsToStop({
    required double userLat,
    required double userLng,
    required double stopLat,
    required double stopLng,
  }) async {
    final routeInfo = await getWalkingRoute(
      startLat: userLat,
      startLng: userLng,
      endLat: stopLat,
      endLng: stopLng,
    );
    
    if (routeInfo != null) {
      return {
        'geometry': routeInfo.geometry,
        'duration': routeInfo.duration,
        'distance': routeInfo.distance,
        'steps': [],
        'summary': 'Walking route',
      };
    }
    
    return null;
  }

  /// Get route directions (legacy method for compatibility)
  static Future<Map<String, dynamic>?> getRouteDirections({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    String profile = 'driving',
  }) async {
    MapboxRouteType routeType;
    switch (profile) {
      case 'walking':
        routeType = MapboxRouteType.walking;
        break;
      case 'cycling':
        routeType = MapboxRouteType.cycling;
        break;
      case 'driving-traffic':
        routeType = MapboxRouteType.drivingTraffic;
        break;
      default:
        routeType = MapboxRouteType.driving;
    }
    
    final routeInfo = await getRouteInfo(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
      routeType: routeType,
    );
    
    if (routeInfo != null) {
      return {
        'geometry': routeInfo.geometry,
        'duration': routeInfo.duration,
        'distance': routeInfo.distance,
        'steps': [],
        'summary': 'Route',
      };
    }
    
    return null;
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
    final accessToken = await _accessToken;
    
    final List<String> coordinates = [];
    coordinates.add('$startLng,$startLat');
    
    if (waypoints != null) {
      for (final waypoint in waypoints) {
        coordinates.add('${waypoint['longitude']},${waypoint['latitude']}');
      }
    }
    
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
        profile: 'driving-traffic',
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

  /// Test method to check if Mapbox service is working
  static Future<bool> testConnection() async {
    try {
      print('🧪 MapboxService: Testing connection...');
      
      final accessToken = await _accessToken;
      
      final Uri uri = Uri.parse('$_baseUrl/geocoding/v5/mapbox.places/Karachi.json')
          .replace(queryParameters: {
        'access_token': accessToken,
        'limit': '1',
      });

      final response = await http.get(uri);
      
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
      
      // Calculate straight-line distance
      final straightLineDistance = DistanceCalculator.calculateDistance(
        karachiCenterLat, karachiCenterLng, fastUniLat, fastUniLng
      );
      print('🧪 MapboxService: Straight-line distance: ${(straightLineDistance / 1000).toStringAsFixed(2)}km');
      
      // Get Mapbox route distance
      final routeInfo = await getRouteInfo(
        startLat: karachiCenterLat,
        startLng: karachiCenterLng,
        endLat: fastUniLat,
        endLng: fastUniLng,
        routeType: MapboxRouteType.driving,
      );
      
      if (routeInfo != null) {
        final mapboxDistance = routeInfo.distance;
        final ratio = mapboxDistance / straightLineDistance;
        
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

  /// Validate route type and return the string representation
  static String _validateRouteType(MapboxRouteType routeType) {
    switch (routeType) {
      case MapboxRouteType.driving:
        return 'driving';
      case MapboxRouteType.walking:
        return 'walking';
      case MapboxRouteType.cycling:
        return 'cycling';
      case MapboxRouteType.drivingTraffic:
        return 'driving-traffic';
      default:
        return 'driving';
    }
  }

  /// Validate that the response has the expected structure
  static bool _isValidDirectionsResponse(Map<String, dynamic> data) {
    if (data == null) return false;
    
    if (!data.containsKey('routes') || !data.containsKey('code')) {
      return false;
    }
    
    if (data['routes'] is! List || (data['routes'] as List).isEmpty) {
      return false;
    }
    
    final firstRoute = data['routes'][0];
    if (firstRoute is! Map<String, dynamic>) {
      return false;
    }
    
    if (!firstRoute.containsKey('distance') || !firstRoute.containsKey('duration')) {
      return false;
    }
    
    final distance = firstRoute['distance'];
    final duration = firstRoute['duration'];
    
    if (distance == null || duration == null) {
      return false;
    }
    
    if (distance is! num || duration is! num) {
      return false;
    }
    
    if (distance < 0 || duration < 0) {
      return false;
    }
    
    return true;
  }
  
  /// Clear cached token (useful for testing or token refresh)
  static void clearCachedToken() {
    _cachedToken = null;
    _isFirstRequest = true;
    print('🧹 MapboxService: Cached token cleared');
  }
  
  /// Reset service state (useful for testing)
  static void reset() {
    _cachedToken = null;
    _isFirstRequest = true;
    print('🔄 MapboxService: Service state reset');
  }
  
  /// Pre-initialize the service to avoid first-time failures
  static Future<bool> initialize() async {
    try {
      print('🚀 MapboxService: Pre-initializing service...');
      
      // Clear rate limit
      await SecureTokenService.clearRateLimit();
      
      // Pre-warm token cache
      await _accessToken;
      
      // Test connection
      final testResult = await testConnection();
      
      if (testResult) {
        _isFirstRequest = false;
        print('✅ MapboxService: Service initialized successfully');
        return true;
      } else {
        print('⚠️ MapboxService: Service initialization failed - connection test failed');
        return false;
      }
    } catch (e) {
      print('❌ MapboxService: Service initialization error: $e');
      return false;
    }
  }
}

// Response classes for Mapbox Directions API
class MapboxDirectionsResponse {
  final List<MapboxRoute> routes;
  final List<MapboxWaypoint> waypoints;
  final String code;
  final String uuid;

  MapboxDirectionsResponse({
    required this.routes,
    required this.waypoints,
    required this.code,
    required this.uuid,
  });

  factory MapboxDirectionsResponse.fromJson(Map<String, dynamic> json) {
    try {
      print('🔍 MapboxDirectionsResponse: Parsing response data...');
      
      // Safely parse routes
      List<MapboxRoute> routes = [];
      if (json['routes'] != null) {
        if (json['routes'] is List) {
          for (int i = 0; i < (json['routes'] as List).length; i++) {
            try {
              final routeData = json['routes'][i];
              if (routeData is Map<String, dynamic>) {
                routes.add(MapboxRoute.fromJson(routeData));
              } else {
                print('⚠️ MapboxDirectionsResponse: Route $i is not a Map, skipping');
              }
            } catch (e) {
              print('❌ MapboxDirectionsResponse: Error parsing route $i: $e');
            }
          }
        } else {
          print('⚠️ MapboxDirectionsResponse: routes is not a List: ${json['routes'].runtimeType}');
        }
      }
      
      // Safely parse waypoints
      List<MapboxWaypoint> waypoints = [];
      if (json['waypoints'] != null) {
        if (json['waypoints'] is List) {
          for (int i = 0; i < (json['waypoints'] as List).length; i++) {
            try {
              final waypointData = json['waypoints'][i];
              if (waypointData is Map<String, dynamic>) {
                waypoints.add(MapboxWaypoint.fromJson(waypointData));
              } else {
                print('⚠️ MapboxDirectionsResponse: Waypoint $i is not a Map, skipping');
              }
            } catch (e) {
              print('❌ MapboxDirectionsResponse: Error parsing waypoint $i: $e');
            }
          }
        } else {
          print('⚠️ MapboxDirectionsResponse: waypoints is not a List: ${json['waypoints'].runtimeType}');
        }
      }
      
      return MapboxDirectionsResponse(
        routes: routes,
        waypoints: waypoints,
        code: _safeString(json['code']),
        uuid: _safeString(json['uuid']),
      );
    } catch (e) {
      print('❌ MapboxDirectionsResponse: Critical error parsing response: $e');
      print('   JSON data: $json');
      rethrow;
    }
  }
  
  /// Safely convert any value to string
  static String _safeString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}

class MapboxRoute {
  final double distance; // in meters
  final double duration; // in seconds
  final List<MapboxLeg> legs;
  final Map<String, dynamic> geometry;
  final double weight;
  final String weightName;

  MapboxRoute({
    required this.distance,
    required this.duration,
    required this.legs,
    required this.geometry,
    required this.weight,
    required this.weightName,
  });

  factory MapboxRoute.fromJson(Map<String, dynamic> json) {
    try {
      print('🔍 MapboxRoute: Parsing route data...');
      
      // Safely parse legs
      List<MapboxLeg> legs = [];
      if (json['legs'] != null) {
        if (json['legs'] is List) {
          for (int i = 0; i < (json['legs'] as List).length; i++) {
            try {
              final legData = json['legs'][i];
              if (legData is Map<String, dynamic>) {
                legs.add(MapboxLeg.fromJson(legData));
              } else {
                print('⚠️ MapboxRoute: Leg $i is not a Map, skipping');
              }
            } catch (e) {
              print('❌ MapboxRoute: Error parsing leg $i: $e');
            }
          }
        } else {
          print('⚠️ MapboxRoute: legs is not a List: ${json['legs'].runtimeType}');
        }
      }
      
      // Handle geometry which can be either a Map or a String
      Map<String, dynamic> geometry = {};
      if (json['geometry'] != null) {
        if (json['geometry'] is Map<String, dynamic>) {
          geometry = json['geometry'] as Map<String, dynamic>;
        } else if (json['geometry'] is String) {
          geometry = {'encoded': json['geometry'] as String};
        } else {
          print('⚠️ MapboxRoute: geometry is neither Map nor String: ${json['geometry'].runtimeType}');
          geometry = {'error': 'Invalid geometry type'};
        }
      }
      
      return MapboxRoute(
        distance: _safeDouble(json['distance']),
        duration: _safeDouble(json['duration']),
        legs: legs,
        geometry: geometry,
        weight: _safeDouble(json['weight']),
        weightName: _safeString(json['weight_name'] ?? 'unknown'),
      );
    } catch (e) {
      print('❌ MapboxRoute: Critical error parsing route: $e');
      print('   Route data: $json');
      rethrow;
    }
  }
  
  /// Safely convert any value to double
  static double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.contains(RegExp(r'^[0-9]+\.?[0-9]*$'))) {
        try {
          return double.parse(value);
        } catch (e) {
          print('⚠️ MapboxRoute: Could not parse numeric string to double: $value');
          return 0.0;
        }
      } else {
        print('ℹ️ MapboxRoute: Ignoring non-numeric string value: $value');
        return 0.0;
      }
    }
    return 0.0;
  }
  
  /// Safely convert any value to string
  static String _safeString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}

class MapboxLeg {
  final double distance;
  final double duration;
  final List<MapboxStep> steps;
  final Map<String, dynamic> summary;

  MapboxLeg({
    required this.distance,
    required this.duration,
    required this.steps,
    required this.summary,
  });

  factory MapboxLeg.fromJson(Map<String, dynamic> json) {
    try {
      print('🔍 MapboxLeg: Parsing leg data...');
      
      // Safely parse steps
      List<MapboxStep> steps = [];
      if (json['steps'] != null) {
        if (json['steps'] is List) {
          for (int i = 0; i < (json['steps'] as List).length; i++) {
            try {
              final stepData = json['steps'][i];
              if (stepData is Map<String, dynamic>) {
                steps.add(MapboxStep.fromJson(stepData));
              } else {
                print('⚠️ MapboxLeg: Step $i is not a Map, skipping');
              }
            } catch (e) {
              print('❌ MapboxLeg: Error parsing step $i: $e');
            }
          }
        } else {
          print('⚠️ MapboxLeg: steps is not a List: ${json['steps'].runtimeType}');
        }
      }
      
      // Handle summary which can be either a Map or a String
      Map<String, dynamic> summary = {};
      if (json['summary'] != null) {
        if (json['summary'] is Map<String, dynamic>) {
          summary = json['summary'] as Map<String, dynamic>;
        } else if (json['summary'] is String) {
          summary = {'text': json['summary'] as String};
        } else {
          print('⚠️ MapboxLeg: summary is neither Map nor String: ${json['summary'].runtimeType}');
          summary = {'error': 'Invalid summary type'};
        }
      }
      
      return MapboxLeg(
        distance: MapboxRoute._safeDouble(json['distance']),
        duration: MapboxRoute._safeDouble(json['duration']),
        steps: steps,
        summary: summary,
      );
    } catch (e) {
      print('❌ MapboxLeg: Critical error parsing leg: $e');
      print('   Leg data: $json');
      rethrow;
    }
  }
}

class MapboxStep {
  final double distance;
  final double duration;
  final String instruction;
  final Map<String, dynamic> geometry;
  final String mode;
  final Map<String, dynamic> maneuver;

  MapboxStep({
    required this.distance,
    required this.duration,
    required this.instruction,
    required this.geometry,
    required this.mode,
    required this.maneuver,
  });

  factory MapboxStep.fromJson(Map<String, dynamic> json) {
    try {
      print('🔍 MapboxStep: Parsing step data...');
      
      // Handle geometry which can be either a Map or a String
      Map<String, dynamic> geometry = {};
      if (json['geometry'] != null) {
        if (json['geometry'] is Map<String, dynamic>) {
          geometry = json['geometry'] as Map<String, dynamic>;
        } else if (json['geometry'] is String) {
          geometry = {'encoded': json['geometry'] as String};
        } else {
          print('⚠️ MapboxStep: geometry is neither Map nor String: ${json['geometry'].runtimeType}');
          geometry = {'error': 'Invalid geometry type'};
        }
      }
      
      // Handle maneuver which can be either a Map or a String
      Map<String, dynamic> maneuver = {};
      if (json['maneuver'] != null) {
        if (json['maneuver'] is Map<String, dynamic>) {
          maneuver = json['maneuver'] as Map<String, dynamic>;
        } else if (json['maneuver'] is String) {
          maneuver = {'type': json['maneuver'] as String};
        } else {
          print('⚠️ MapboxStep: maneuver is neither Map nor String: ${json['maneuver'].runtimeType}');
          maneuver = {'error': 'Invalid maneuver type'};
        }
      }
      
      return MapboxStep(
        distance: MapboxRoute._safeDouble(json['distance']),
        duration: MapboxRoute._safeDouble(json['duration']),
        instruction: _safeString(json['instruction']),
        geometry: geometry,
        mode: _safeString(json['mode']),
        maneuver: maneuver,
      );
    } catch (e) {
      print('❌ MapboxStep: Critical error parsing step: $e');
      print('   Step data: $json');
      rethrow;
    }
  }
  
  /// Safely convert any value to string
  static String _safeString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}

class MapboxWaypoint {
  final double distance;
  final String name;
  final List<double> location;

  MapboxWaypoint({
    required this.distance,
    required this.name,
    required this.location,
  });

  factory MapboxWaypoint.fromJson(Map<String, dynamic> json) {
    try {
      print('🔍 MapboxWaypoint: Parsing waypoint data...');
      
      // Safely parse location array
      List<double> location = [0.0, 0.0];
      if (json['location'] != null) {
        if (json['location'] is List) {
          final locationList = json['location'] as List;
          if (locationList.length >= 2) {
            try {
              location = [
                MapboxRoute._safeDouble(locationList[0]),
                MapboxRoute._safeDouble(locationList[1]),
              ];
            } catch (e) {
              print('❌ MapboxWaypoint: Error parsing location coordinates: $e');
            }
          } else {
            print('⚠️ MapboxWaypoint: location array has less than 2 elements');
          }
        } else {
          print('⚠️ MapboxWaypoint: location is not a List: ${json['location'].runtimeType}');
        }
      }
      
      return MapboxWaypoint(
        distance: MapboxRoute._safeDouble(json['distance']),
        name: MapboxStep._safeString(json['name']),
        location: location,
      );
    } catch (e) {
      print('❌ MapboxWaypoint: Critical error parsing waypoint: $e');
      print('   Waypoint data: $json');
      rethrow;
    }
  }
}

class MapboxRouteInfo {
  final double distance; // in meters (as returned by Mapbox)
  final double duration; // in seconds
  final MapboxRouteType routeType;
  final Map<String, dynamic>? geometry;

  MapboxRouteInfo({
    required this.distance,
    required this.duration,
    required this.routeType,
    this.geometry,
  }) {
    // Validate that distance is reasonable (Mapbox returns distance in meters)
    if (distance < 0) {
      print('⚠️ MapboxRouteInfo: Negative distance detected: $distance meters');
    }
    if (distance > 1000000) { // 1000 km
      print('⚠️ MapboxRouteInfo: Unusually large distance detected: $distance meters');
    }
  }

  /// Get formatted distance string (Mapbox returns distance in meters)
  String get formattedDistance {
    if (distance < 0) {
      return 'Invalid distance';
    }
    if (distance < 1000) {
      return '${distance.round()}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }

  /// Get formatted duration string
  String get formattedDuration {
    final minutes = (duration / 60).round();
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

  /// Get duration in minutes
  int get durationMinutes => (duration / 60).round();

  /// Get distance in kilometers
  double get distanceKm => distance / 1000;
}

 