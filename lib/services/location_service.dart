import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  bool _isLoading = false;
  String? _error;
  bool _permissionGranted = false;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get permissionGranted => _permissionGranted;

  Future<void> initializeLocation() async {
    _setLoading(true);
    _error = null;
    
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable GPS.');
      }

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied. Please grant location access.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Please enable in settings.');
      }

      _permissionGranted = true;
      
      // Get current position
      await getCurrentLocation();
      
    } catch (e) {
      _error = e.toString();
      print('Location initialization error: $e');
      // Fallback to Gadap Town coordinates instead of Karachi center
      _currentPosition = Position(
        longitude: 67.1234, // Gadap Town area longitude
        latitude: 24.9876,  // Gadap Town area latitude
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> getCurrentLocation() async {
    if (!_permissionGranted) {
      await initializeLocation();
      return;
    }
    
    _setLoading(true);
    _error = null;
    
    try {
      // Try to get last known position first (faster)
      Position? lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        print('Using last known position: ${lastKnownPosition.latitude}, ${lastKnownPosition.longitude}');
        _currentPosition = lastKnownPosition;
        _setLoading(false);
        return;
      }

      // Get current position with better accuracy settings
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
        forceAndroidLocationManager: false, // Use Google Play Services if available
      );
      
      print('Got current position: ${position.latitude}, ${position.longitude}');
      _currentPosition = position;
      
    } catch (e) {
      _error = 'Failed to get current location: ${e.toString()}';
      print('Location error: $e');
      
      // Use last known position or fallback to Gadap Town
      if (_currentPosition == null) {
        _currentPosition = Position(
          longitude: 67.1234, // Gadap Town area longitude
          latitude: 24.9876,  // Gadap Town area latitude
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
        print('Using fallback coordinates for Gadap Town area');
      }
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
