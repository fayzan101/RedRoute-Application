import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class GeocodingService {
  /// Get address from coordinates (reverse geocoding)
  static Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return _formatAddress(place);
  }
      return null;
    } catch (e) {
      print('Error getting address from coordinates: $e');
      return null;
    }
  }

  /// Get coordinates from address (forward geocoding)
  static Future<Position?> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      
      if (locations.isNotEmpty) {
        Location location = locations[0];
        return Position(
          latitude: location.latitude,
          longitude: location.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
          );
      }
      return null;
    } catch (e) {
      print('Error getting coordinates from address: $e');
      return null;
    }
  }

  /// Search for places by query string
  static Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    try {
      List<Location> locations = await locationFromAddress(query);
      
      List<Map<String, dynamic>> results = [];
      for (Location location in locations) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );
        
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          results.add({
            'name': _formatAddress(place),
            'latitude': location.latitude,
            'longitude': location.longitude,
            'placemark': place,
          });
        }
      }
      
      return results;
    } catch (e) {
      print('Error searching places: $e');
      return [];
  }
}

  /// Format address from Placemark
  static String _formatAddress(Placemark place) {
    List<String> addressParts = [];
    
    if (place.street != null && place.street!.isNotEmpty) {
      addressParts.add(place.street!);
    }
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      addressParts.add(place.subLocality!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      addressParts.add(place.locality!);
    }
    if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
      addressParts.add(place.administrativeArea!);
    }
    if (place.country != null && place.country!.isNotEmpty) {
      addressParts.add(place.country!);
    }
    
    return addressParts.join(', ');
  }

  /// Get current location address
  static Future<String?> getCurrentLocationAddress() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      return await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      print('Error getting current location address: $e');
      return null;
    }
  }
}