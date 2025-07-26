import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'secure_token_service.dart';

/// Route types supported by Mapbox Directions API
enum MapboxRouteType {
  driving,        // Standard driving route
  walking,        // Walking route
  cycling,        // Cycling route
  drivingTraffic, // Real-time traffic driving route
}

class MapboxDirectionsService {
  static const String _baseUrl = ApiConfig.mapboxBaseUrl;
  
  /// Get access token securely
  static Future<String> get _accessToken async {
    final token = await SecureTokenService.getToken();
    if (token != null && SecureTokenService.isValidToken(token)) {
      return token;
    }
    return ApiConfig.mapboxAccessToken;
  }

  /// Get directions between two points
  static Future<MapboxDirectionsResponse?> getDirections({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    MapboxRouteType routeType = MapboxRouteType.drivingTraffic,
    List<double>? waypoints, // Optional intermediate points
    bool alternatives = false, // Get alternative routes
    bool steps = true, // Include turn-by-turn instructions
    bool annotations = true, // Include metadata like speed, duration
    String overview = 'full', // Route geometry
    bool continueStraight = true,
  }) async {
    try {
      print('🗺️ MapboxDirectionsService: Getting directions from ($startLat, $startLng) to ($endLat, $endLng)');
      
      // Validate coordinates are within reasonable bounds
      if (!_isValidCoordinate(startLat, startLng) || !_isValidCoordinate(endLat, endLng)) {
        print('❌ MapboxDirectionsService: Invalid coordinates provided');
        print('   Start: ($startLat, $startLng)');
        print('   End: ($endLat, $endLng)');
        print('   Expected: lat -90 to 90, lng -180 to 180');
        return null;
      }
      
      // Test network connectivity first
      final isConnected = await SecureTokenService.isRateLimited();
      if (isConnected) {
        print('❌ MapboxDirectionsService: Rate limited, skipping request');
        return null;
      }
      
      // Get access token securely
      final accessToken = await _accessToken;
      
      // Validate access token has directions scope
      if (!_hasDirectionsScope(accessToken)) {
        
      }
      
      // Build coordinates string in longitude,latitude format (Mapbox requirement)
      String coordinates = '$startLng,$startLat';
      if (waypoints != null && waypoints.isNotEmpty) {
        for (int i = 0; i < waypoints.length; i += 2) {
          if (i + 1 < waypoints.length) {
            coordinates += ';${waypoints[i]},${waypoints[i + 1]}'; // Fix: lng,lat format
          }
        }
      }
      coordinates += ';$endLng,$endLat';
      
      // Validate route type
      String routeTypeStr = _validateRouteType(routeType);
      
      // Build query parameters with required values
      final Map<String, String> queryParams = {
        'access_token': accessToken,
        'geometries': 'geojson',
        'overview': 'full',
        'steps': steps.toString(),
        'continue_straight': continueStraight.toString(),
        'alternatives': alternatives.toString(),
      };
      
      // Add annotations only if requested and with proper format
      if (annotations) {
        queryParams['annotations'] = 'duration,distance,congestion,speed';
      }
      
      // Use Uri.https() instead of Uri.parse().replace() to avoid query string errors
      final Uri uri = Uri.https(
        'api.mapbox.com',
        '/directions/v5/mapbox/$routeTypeStr/$coordinates',
        queryParams,
      );

      // Log the full URI for debugging (with token masked)
      final debugUri = uri.toString().replaceAll(accessToken, '***');
      
      
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      
      
      
      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = json.decode(response.body);
          
          
          // Validate response structure
          if (!_isValidDirectionsResponse(data)) {
            
            return null;
          }
          
          final directionsResponse = MapboxDirectionsResponse.fromJson(data);
          
          // Log route information for debugging
          if (directionsResponse.routes.isNotEmpty) {
            final route = directionsResponse.routes.first;
            print('📏 MapboxDirectionsService: Route distance: ${route.distance}m, duration: ${route.duration}s');
          }
          
          return directionsResponse;
        } catch (e) {
         
          
          return null;
        }
      } else if (response.statusCode == 422) {
        
        return null;
      } else {
        print('❌ MapboxDirectionsService: HTTP Error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ MapboxDirectionsService: Error getting directions: $e');
      
      // Provide specific error messages for common issues
      if (e.toString().contains('SocketException')) {
        print('   Network error: Please check your internet connection');
      } else if (e.toString().contains('TimeoutException')) {
        print('   Request timeout: Please try again');
      } else if (e.toString().contains('HandshakeException')) {
        print('   HTTPS error: Please check your network security settings');
      }
      
      return null;
    }
  }

  /// Get distance and time for a route
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
        steps: false,
        annotations: true,
      );
      
      if (response != null && response.routes.isNotEmpty) {
        final route = response.routes.first;
        return MapboxRouteInfo(
          distance: route.distance,
          duration: route.duration,
          routeType: routeType,
          geometry: route.geometry,
        );
      }
      
      return null;
    } catch (e) {
      print('❌ MapboxDirectionsService: Error getting route info: $e');
      return null;
    }
  }

  /// Get multiple route options
  static Future<List<MapboxRouteInfo>> getRouteAlternatives({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    MapboxRouteType routeType = MapboxRouteType.drivingTraffic,
    int maxAlternatives = 3,
  }) async {
    try {
      final response = await getDirections(
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
        routeType: routeType,
        alternatives: true,
        steps: false,
        annotations: true,
      );
      
      if (response != null) {
        return response.routes.take(maxAlternatives).map((route) => MapboxRouteInfo(
          distance: route.distance,
          duration: route.duration,
          routeType: routeType,
          geometry: route.geometry,
        )).toList();
      }
      
      return [];
    } catch (e) {
      print('❌ MapboxDirectionsService: Error getting route alternatives: $e');
      return [];
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
  
  /// Validate if coordinates are within valid geographic bounds
  static bool _isValidCoordinate(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
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
        return 'driving'; // Use 'driving' instead of 'driving-traffic' for better compatibility
      default:
        return 'driving'; // Default fallback
    }
  }

  /// Check if access token has the 'directions' scope
  static bool _hasDirectionsScope(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) {
        return false;
      }
      // Add padding to base64 string if needed
      String padded = parts[1];
      while (padded.length % 4 != 0) {
        padded += '=';
      }
      final payload = json.decode(utf8.decode(base64Url.decode(padded)));
      return payload['scope']?.contains('directions') ?? false;
    } catch (e) {
      print('⚠️ MapboxDirectionsService: Could not parse token scope: $e');
      return true; // Assume it has directions scope if we can't parse
    }
  }

  /// Validate that the response has the expected structure
  static bool _isValidDirectionsResponse(Map<String, dynamic> data) {
    if (data == null) return false;
    
    // Check for required top-level fields
    if (!data.containsKey('routes') || !data.containsKey('code')) {
      return false;
    }
    
    // Check that routes is a list and has at least one route
    if (data['routes'] is! List || (data['routes'] as List).isEmpty) {
      return false;
    }
    
    // Check that the first route has required fields
    final firstRoute = data['routes'][0];
    if (firstRoute is! Map<String, dynamic>) {
      return false;
    }
    
    // Check for required route fields (distance and duration)
    if (!firstRoute.containsKey('distance') || !firstRoute.containsKey('duration')) {
      return false;
    }
    
    // Validate that distance and duration are numeric
    final distance = firstRoute['distance'];
    final duration = firstRoute['duration'];
    
    if (distance == null || duration == null) {
      return false;
    }
    
    // Check if they're numeric
    if (distance is! num || duration is! num) {
      return false;
    }
    
    // Allow zero or small positive values (some routes might be very short)
    if (distance < 0 || duration < 0) {
      return false;
    }
    
    // Log validation success for debugging
    print('✅ MapboxDirectionsService: Response validation passed');
    print('   Distance: $distance meters');
    print('   Duration: $duration seconds');
    
    return true;
  }
}

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
  final String weightName; // Changed from double to String

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
          // If geometry is a string (encoded polyline), store it as a map with the string
          geometry = {'encoded': json['geometry'] as String};
        } else {
          print('⚠️ MapboxRoute: geometry is neither Map nor String: ${json['geometry'].runtimeType}');
          geometry = {'error': 'Invalid geometry type'};
        }
      }
      
      // Debug: Log all fields to identify problematic ones
      print('🔍 MapboxRoute: Parsing fields:');
      json.forEach((key, value) {
        print('   $key: $value (${value.runtimeType})');
        // Check if we're trying to parse a string as a number for numeric fields (excluding weight_name which is a string)
        if ((key == 'distance' || key == 'duration' || key == 'weight') && 
            value is String && !value.contains(RegExp(r'^[0-9]+\.?[0-9]*$'))) {
          print('   ⚠️ WARNING: Field $key contains non-numeric string: $value');
        }
      });
      
      return MapboxRoute(
        distance: _safeDouble(json['distance']),
        duration: _safeDouble(json['duration']),
        legs: legs,
        geometry: geometry,
        weight: _safeDouble(json['weight']),
        weightName: _safeString(json['weight_name'] ?? 'unknown'), // Handle as string
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
      // Check if it's a numeric string
      if (value.contains(RegExp(r'^[0-9]+\.?[0-9]*$'))) {
        try {
          return double.parse(value);
        } catch (e) {
          print('⚠️ MapboxRoute: Could not parse numeric string to double: $value');
          return 0.0;
        }
      } else {
        // It's a non-numeric string like "pedestrian", "driving", etc.
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
          // If geometry is a string (encoded polyline), store it as a map with the string
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