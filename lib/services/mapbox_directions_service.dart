import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'secure_token_service.dart';

/// Route types supported by Mapbox Directions API
enum MapboxRouteType {
  driving,
  walking,
  cycling,
  drivingTraffic, // Real-time traffic
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
      
      // Check rate limiting
      if (await SecureTokenService.isRateLimited()) {
        print('⚠️ MapboxDirectionsService: Rate limited, skipping request');
        return null;
      }
      
      // Get access token securely
      final accessToken = await _accessToken;
      
      // Build coordinates string
      String coordinates = '$startLng,$startLat';
      if (waypoints != null && waypoints.isNotEmpty) {
        for (int i = 0; i < waypoints.length; i += 2) {
          if (i + 1 < waypoints.length) {
            coordinates += ';${waypoints[i + 1]},${waypoints[i]}';
          }
        }
      }
      coordinates += ';$endLng,$endLat';
      
      // Build query parameters
      final Map<String, String> queryParams = {
        'access_token': accessToken,
        'geometries': 'geojson',
        'steps': steps.toString(),
        'annotations': annotations.toString(),
        'overview': overview.toString(),
        'continue_straight': continueStraight.toString(),
        'alternatives': alternatives.toString(),
      };
      
      // Add route type
      String routeTypeStr = routeType.name;
      if (routeType == MapboxRouteType.drivingTraffic) {
        routeTypeStr = 'driving-traffic';
      }
      
      final Uri uri = Uri.parse('$_baseUrl/directions/v5/mapbox/$routeTypeStr/$coordinates')
          .replace(queryParameters: queryParams);

      print('🌐 MapboxDirectionsService: Making request to ${uri.toString().replaceAll(accessToken, '***')}');
      
      final response = await http.get(uri);
      
      print('📡 MapboxDirectionsService: Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return MapboxDirectionsResponse.fromJson(data);
      } else {
        print('❌ MapboxDirectionsService: HTTP Error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ MapboxDirectionsService: Error getting directions: $e');
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

  /// Test connection to Mapbox Directions API
  static Future<bool> testConnection() async {
    try {
      // Test with a simple route in Karachi
      const double startLat = 24.8607;
      const double startLng = 67.0011;
      const double endLat = 24.8607;
      const double endLng = 67.0012;
      
      final response = await getDirections(
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
        routeType: MapboxRouteType.driving,
        steps: false,
        annotations: false,
      );
      
      return response != null;
    } catch (e) {
      print('❌ MapboxDirectionsService: Connection test failed: $e');
      return false;
    }
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
    return MapboxDirectionsResponse(
      routes: (json['routes'] as List?)
          ?.map((route) => MapboxRoute.fromJson(route))
          .toList() ?? [],
      waypoints: (json['waypoints'] as List?)
          ?.map((waypoint) => MapboxWaypoint.fromJson(waypoint))
          .toList() ?? [],
      code: json['code'] ?? '',
      uuid: json['uuid'] ?? '',
    );
  }
}

class MapboxRoute {
  final double distance; // in meters
  final double duration; // in seconds
  final List<MapboxLeg> legs;
  final Map<String, dynamic> geometry;
  final double weight;
  final double weightName;

  MapboxRoute({
    required this.distance,
    required this.duration,
    required this.legs,
    required this.geometry,
    required this.weight,
    required this.weightName,
  });

  factory MapboxRoute.fromJson(Map<String, dynamic> json) {
    return MapboxRoute(
      distance: (json['distance'] ?? 0.0).toDouble(),
      duration: (json['duration'] ?? 0.0).toDouble(),
      legs: (json['legs'] as List?)
          ?.map((leg) => MapboxLeg.fromJson(leg))
          .toList() ?? [],
      geometry: json['geometry'] ?? {},
      weight: (json['weight'] ?? 0.0).toDouble(),
      weightName: (json['weight_name'] ?? 0.0).toDouble(),
    );
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
    return MapboxLeg(
      distance: (json['distance'] ?? 0.0).toDouble(),
      duration: (json['duration'] ?? 0.0).toDouble(),
      steps: (json['steps'] as List?)
          ?.map((step) => MapboxStep.fromJson(step))
          .toList() ?? [],
      summary: json['summary'] ?? {},
    );
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
    return MapboxStep(
      distance: (json['distance'] ?? 0.0).toDouble(),
      duration: (json['duration'] ?? 0.0).toDouble(),
      instruction: json['instruction'] ?? '',
      geometry: json['geometry'] ?? {},
      mode: json['mode'] ?? '',
      maneuver: json['maneuver'] ?? {},
    );
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
    return MapboxWaypoint(
      distance: (json['distance'] ?? 0.0).toDouble(),
      name: json['name'] ?? '',
      location: List<double>.from(json['location'] ?? [0.0, 0.0]),
    );
  }
}

class MapboxRouteInfo {
  final double distance; // in meters
  final double duration; // in seconds
  final MapboxRouteType routeType;
  final Map<String, dynamic>? geometry;

  MapboxRouteInfo({
    required this.distance,
    required this.duration,
    required this.routeType,
    this.geometry,
  });

  /// Get formatted distance string
  String get formattedDistance {
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