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
      // Fallback to Karachi center coordinates for demo
      _currentPosition = Position(
        longitude: 67.0011,
        latitude: 24.8607,
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
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      _currentPosition = position;
      
    } catch (e) {
      _error = 'Failed to get current location: ${e.toString()}';
      // Use last known position or fallback
      if (_currentPosition == null) {
        _currentPosition = Position(
          longitude: 67.0011,
          latitude: 24.8607,
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
