import 'dart:convert';
import 'package:http/http.dart' as http;

class MapboxService {
  static const String _baseUrl = 'https://api.mapbox.com';
  static const String _accessToken = 'pk.eyJ1IjoibXRhYWhhIiwiYSI6ImNtYzhzNDdxYTBoYTgydnM5Y25sOWUxNW4ifQ.LNtkLKq7wVti_5_MyaBY-w';
  
  /// Search for places using Mapbox Geocoding API
  static Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    try {
      print('🔍 MapboxService: Searching for "$query"');
      
      // Focus search on Karachi, Pakistan
      const String karachiBbox = '66.8,24.7,67.4,25.2'; // Karachi bounding box
      const String country = 'pk'; // Pakistan country code
      
      // Try multiple search variations to get better results
      List<String> searchVariations = [
        query,
        '$query, Karachi',
        '$query, Pakistan',
      ];
      
      // Add Karachi-specific variations for better results
      if (!query.toLowerCase().contains('karachi')) {
        searchVariations.add('$query Karachi');
      }
      
      List<Map<String, dynamic>> allResults = [];
      
      for (String searchQuery in searchVariations) {
        try {
          final Uri uri = Uri.parse('$_baseUrl/geocoding/v5/mapbox.places/$searchQuery.json')
              .replace(queryParameters: {
            'access_token': _accessToken,
            'bbox': karachiBbox,
            'country': country,
            'types': 'poi,place,neighborhood,address,locality',
            'limit': '15',
            'language': 'en',
            'autocomplete': 'true',
          });

          print('🌐 MapboxService: Making request to ${uri.toString().replaceAll(_accessToken, '***')}');
          
          final response = await http.get(uri);
          
          print('📡 MapboxService: Response status: ${response.statusCode}');
          
          if (response.statusCode == 200) {
            final Map<String, dynamic> data = json.decode(response.body);
            final List<dynamic> features = data['features'] ?? [];
            
            print('📍 MapboxService: Found ${features.length} features for "$searchQuery"');
            
            final results = features.map<Map<String, dynamic>>((feature) {
              final Map<String, dynamic> properties = feature['properties'] ?? {};
              final List<double> coordinates = List<double>.from(feature['geometry']['coordinates'] ?? [0.0, 0.0]);
              
              return {
                'name': _extractName(feature),
                'latitude': coordinates[1],
                'longitude': coordinates[0],
                'formattedAddress': feature['place_name'] ?? '',
                'type': feature['place_type']?.first ?? 'unknown',
                'relevance': feature['relevance'] ?? 0.0,
                'properties': properties,
                'feature': feature,
                'searchQuery': searchQuery,
              };
            }).toList();
            
            allResults.addAll(results);
          } else {
            print('❌ MapboxService: HTTP Error ${response.statusCode}: ${response.body}');
          }
        } catch (e) {
          print('❌ MapboxService: Error with search variation "$searchQuery": $e');
          continue;
        }
      }
      
      print('📊 MapboxService: Total results before deduplication: ${allResults.length}');
      
      // Remove duplicates and sort by relevance
      final Map<String, Map<String, dynamic>> uniqueResults = {};
      for (final result in allResults) {
        final key = '${result['name']}_${result['latitude']}_${result['longitude']}';
        if (!uniqueResults.containsKey(key) || 
            (result['relevance'] ?? 0.0) > (uniqueResults[key]?['relevance'] ?? 0.0)) {
          uniqueResults[key] = result;
        }
      }
      
      final sortedResults = uniqueResults.values.toList();
      sortedResults.sort((a, b) => (b['relevance'] ?? 0.0).compareTo(a['relevance'] ?? 0.0));
      
      print('✅ MapboxService: Returning ${sortedResults.length} unique results');
      for (final result in sortedResults.take(3)) {
        print('   - ${result['name']} (${result['relevance']})');
      }
      
      return sortedResults;
    } catch (e) {
      print('❌ MapboxService: General error searching places: $e');
      return [];
    }
  }

  /// Get address from coordinates (reverse geocoding)
  static Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      final Uri uri = Uri.parse('$_baseUrl/geocoding/v5/mapbox.places/$longitude,$latitude.json')
          .replace(queryParameters: {
        'access_token': _accessToken,
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
      const String karachiBbox = '66.8,24.7,67.4,25.2';
      const String country = 'pk';
      
      final Uri uri = Uri.parse('$_baseUrl/geocoding/v5/mapbox.places/$address.json')
          .replace(queryParameters: {
        'access_token': _accessToken,
        'bbox': karachiBbox,
        'country': country,
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
  static Future<List<Map<String, dynamic>>> searchBRTStops(String query) async {
    try {
      const String karachiBbox = '66.8,24.7,67.4,25.2';
      const String country = 'pk';
      
      // Add BRT-specific terms to improve search
      String searchQuery = query;
      if (!query.toLowerCase().contains('brt') && !query.toLowerCase().contains('bus')) {
        searchQuery = '$query BRT bus stop';
      }
      
      final Uri uri = Uri.parse('$_baseUrl/geocoding/v5/mapbox.places/$searchQuery.json')
          .replace(queryParameters: {
        'access_token': _accessToken,
        'bbox': karachiBbox,
        'country': country,
        'types': 'poi',
        'limit': '10',
        'language': 'en',
      });

      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> features = data['features'] ?? [];
        
        return features.where((feature) {
          final String name = _extractName(feature).toLowerCase();
          final String category = feature['properties']?['category']?.toString().toLowerCase() ?? '';
          
          // Filter for BRT-related places
          return name.contains('brt') || 
                 name.contains('bus') || 
                 name.contains('stop') ||
                 category.contains('transport') ||
                 category.contains('bus');
        }).map<Map<String, dynamic>>((feature) {
          final List<double> coordinates = List<double>.from(feature['geometry']['coordinates'] ?? [0.0, 0.0]);
          
          return {
            'name': _extractName(feature),
            'latitude': coordinates[1],
            'longitude': coordinates[0],
            'formattedAddress': feature['place_name'] ?? '',
            'type': 'brt_stop',
            'relevance': feature['relevance'] ?? 0.0,
            'properties': feature['properties'] ?? {},
          };
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error searching BRT stops: $e');
      return [];
    }
  }

  /// Extract the best name from a Mapbox feature
  static String _extractName(Map<String, dynamic> feature) {
    final Map<String, dynamic> properties = feature['properties'] ?? {};
    final String placeName = feature['place_name'] ?? '';
    
    // Try to get the most specific name
    if (properties['name'] != null && properties['name'].toString().isNotEmpty) {
      return properties['name'];
    }
    
    if (properties['short_name'] != null && properties['short_name'].toString().isNotEmpty) {
      return properties['short_name'];
    }
    
    // Extract from place_name (remove country and city parts)
    if (placeName.isNotEmpty) {
      final parts = placeName.split(', ');
      if (parts.length > 1) {
        // Return the first part (most specific)
        return parts.first;
      }
      return placeName;
    }
    
    return 'Unknown Location';
  }

  /// Get nearby places around a location
  static Future<List<Map<String, dynamic>>> getNearbyPlaces(
    double latitude, 
    double longitude, 
    {double radius = 1000}
  ) async {
    try {
      final Uri uri = Uri.parse('$_baseUrl/geocoding/v5/mapbox.places/nearby.json')
          .replace(queryParameters: {
        'access_token': _accessToken,
        'proximity': '$longitude,$latitude',
        'types': 'poi,place',
        'limit': '10',
        'language': 'en',
      });

      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> features = data['features'] ?? [];
        
        return features.map<Map<String, dynamic>>((feature) {
          final List<double> coordinates = List<double>.from(feature['geometry']['coordinates'] ?? [0.0, 0.0]);
          
          return {
            'name': _extractName(feature),
            'latitude': coordinates[1],
            'longitude': coordinates[0],
            'formattedAddress': feature['place_name'] ?? '',
            'type': feature['place_type']?.first ?? 'unknown',
            'relevance': feature['relevance'] ?? 0.0,
            'properties': feature['properties'] ?? {},
          };
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error getting nearby places: $e');
      return [];
    }
  }

  /// Get route directions between two points
  static Future<Map<String, dynamic>?> getRouteDirections({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    String profile = 'driving', // driving, walking, cycling, driving-traffic
  }) async {
    try {
      final Uri uri = Uri.parse('$_baseUrl/directions/v5/mapbox/$profile/$startLng,$startLat;$endLng,$endLat.json')
          .replace(queryParameters: {
        'access_token': _accessToken,
        'geometries': 'geojson',
        'overview': 'full',
        'steps': 'true',
        'annotations': 'duration,distance',
        'language': 'en',
      });

      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> routes = data['routes'] ?? [];
        
        if (routes.isNotEmpty) {
          final route = routes.first;
          return {
            'geometry': route['geometry'],
            'duration': route['duration'],
            'distance': route['distance'],
            'steps': route['legs']?.first?['steps'] ?? [],
            'summary': route['legs']?.first?['summary'] ?? '',
          };
        }
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
  static String getStaticMapUrl({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    List<Map<String, double>>? waypoints,
    int width = 400,
    int height = 300,
    double zoom = 12,
  }) {
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
    
    return '$_baseUrl/styles/v1/mapbox/streets-v11/static/path-5+E53E3E-1($path)/$startLng,$startLat,$zoom/$width x $height?access_token=$_accessToken&padding=50';
  }

  /// Get static map URL for bus route with stops
  static String getBusRouteMapUrl({
    required List<Map<String, double>> stops,
    int width = 400,
    int height = 300,
  }) {
    if (stops.isEmpty) return '';
    
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
    
    return '$_baseUrl/styles/v1/mapbox/streets-v11/static/path-5+E53E3E-1($path)/$centerLng,$centerLat,$zoom/$width x $height?access_token=$_accessToken&padding=50';
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
  static Future<List<Map<String, dynamic>>> getNearbyTransportOptions({
    required double latitude,
    required double longitude,
    double radius = 1000,
  }) async {
    try {
      final Uri uri = Uri.parse('$_baseUrl/geocoding/v5/mapbox.places/nearby.json')
          .replace(queryParameters: {
        'access_token': _accessToken,
        'proximity': '$longitude,$latitude',
        'types': 'poi',
        'limit': '20',
        'language': 'en',
      });

      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> features = data['features'] ?? [];
        
        return features.where((feature) {
          final String name = _extractName(feature).toLowerCase();
          final String category = feature['properties']?['category']?.toString().toLowerCase() ?? '';
          
          // Filter for transport-related places
          return name.contains('bus') || 
                 name.contains('stop') ||
                 name.contains('station') ||
                 name.contains('terminal') ||
                 name.contains('brt') ||
                 category.contains('transport') ||
                 category.contains('bus') ||
                 category.contains('station');
        }).map<Map<String, dynamic>>((feature) {
          final List<double> coordinates = List<double>.from(feature['geometry']['coordinates'] ?? [0.0, 0.0]);
          
          return {
            'name': _extractName(feature),
            'latitude': coordinates[1],
            'longitude': coordinates[0],
            'formattedAddress': feature['place_name'] ?? '',
            'type': 'transport',
            'distance': feature['relevance'] ?? 0.0,
            'properties': feature['properties'] ?? {},
          };
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error getting nearby transport options: $e');
      return [];
    }
  }

  /// Get traffic information for a route
  static Future<Map<String, dynamic>?> getTrafficInfo({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    try {
      final Uri uri = Uri.parse('$_baseUrl/directions/v5/mapbox/driving-traffic/$startLng,$startLat;$endLng,$endLat.json')
          .replace(queryParameters: {
        'access_token': _accessToken,
        'annotations': 'duration,distance',
      });

      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> routes = data['routes'] ?? [];
        
        if (routes.isNotEmpty) {
          final route = routes.first;
          return {
            'duration': route['duration'],
            'distance': route['distance'],
            'trafficLevel': _calculateTrafficLevel(route['duration'] ?? 0),
          };
        }
      }
      return null;
    } catch (e) {
      print('Error getting traffic info: $e');
      return null;
    }
  }

  /// Calculate traffic level based on duration
  static String _calculateTrafficLevel(double duration) {
    // This is a simplified calculation - in a real app you'd compare with normal duration
    if (duration < 600) return 'Low';
    if (duration < 1200) return 'Medium';
    return 'High';
  }

  /// Test method to check if Mapbox service is working
  static Future<bool> testConnection() async {
    try {
      print('🧪 MapboxService: Testing connection...');
      
      final Uri uri = Uri.parse('$_baseUrl/geocoding/v5/mapbox.places/Karachi.json')
          .replace(queryParameters: {
        'access_token': _accessToken,
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
} 