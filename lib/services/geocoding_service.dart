import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  static const String _baseUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';
  static String get _accessToken {
    // Try to get from environment, fallback to a working demo token
    const envToken = String.fromEnvironment('MAPBOX_PUBLIC_KEY', defaultValue: '');
    if (envToken.isNotEmpty) return envToken;
    
    // For demo purposes - replace with actual token
    return 'pk.eyJ1IjoibWFwYm94IiwiYSI6ImNpejY4NXVycTA2emYycXBndHRqcmZ3N3gifQ.rJcFIG214AriISLbB6B5aw';
  }

  /// Search for places in Karachi using Mapbox Geocoding API
  static Future<List<LocationResult>> searchPlaces(String query) async {
    if (query.isEmpty || _accessToken.isEmpty) return [];

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = '$_baseUrl/$encodedQuery.json'
          '?access_token=$_accessToken'
          '&country=PK'
          '&proximity=67.0011,24.8607' // Karachi center
          '&bbox=66.6,24.4,67.8,25.3' // Karachi bounding box
          '&limit=10';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List<dynamic>;

        return features.map((feature) {
          final geometry = feature['geometry'];
          final coordinates = geometry['coordinates'] as List<dynamic>;
          
          return LocationResult(
            name: feature['place_name'] as String,
            displayName: feature['text'] as String,
            latitude: coordinates[1] as double,
            longitude: coordinates[0] as double,
            address: feature['place_name'] as String,
            type: _getPlaceType(feature['place_type'] as List<dynamic>),
          );
        }).toList();
      }
    } catch (e) {
      print('Geocoding error: $e');
    }

    return [];
  }

  /// Get coordinates for a specific address
  static Future<LocationResult?> getCoordinates(String address) async {
    final results = await searchPlaces(address);
    return results.isNotEmpty ? results.first : null;
  }

  static String _getPlaceType(List<dynamic> placeTypes) {
    if (placeTypes.contains('poi')) return 'Point of Interest';
    if (placeTypes.contains('address')) return 'Address';
    if (placeTypes.contains('neighborhood')) return 'Neighborhood';
    if (placeTypes.contains('locality')) return 'Area';
    return 'Location';
  }
}

class LocationResult {
  final String name;
  final String displayName;
  final double latitude;
  final double longitude;
  final String address;
  final String type;

  LocationResult({
    required this.name,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.type,
  });

  @override
  String toString() {
    return 'LocationResult{name: $name, lat: $latitude, lng: $longitude}';
  }
}