import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'mapbox_service.dart';

class EnhancedLocationService extends ChangeNotifier {
  Position? _currentPosition;
  bool _isLoading = false;
  String? _error;
  bool _permissionGranted = false;
  String? _currentAddress;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get permissionGranted => _permissionGranted;
  String? get currentAddress => _currentAddress;

  Future<void> initializeLocation() async {
    _setLoading(true);
    _error = null;
    
    try {
      print('📍 LocationService: Initializing location services...');
      
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable GPS in your device settings.');
      }

      print('📍 LocationService: Location services are enabled');

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      print('📍 LocationService: Current permission status: $permission');
      
      if (permission == LocationPermission.denied) {
        print('📍 LocationService: Requesting location permission...');
        permission = await Geolocator.requestPermission();
        print('📍 LocationService: Permission result: $permission');
        
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied. Please grant location access in app settings.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Please enable location access in your device settings.');
      }

      _permissionGranted = true;
      print('📍 LocationService: Location permissions granted');
      
      // Get current position
      await getCurrentLocation();
      
    } catch (e) {
      _error = e.toString();
      print('❌ LocationService: Initialization error: $e');
      
      // Don't set fallback coordinates silently - let the user know there's an issue
      _currentPosition = null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> getCurrentLocation() async {
    if (!_permissionGranted) {
      print('📍 LocationService: Permissions not granted, initializing...');
      await initializeLocation();
      return;
    }
    
    _setLoading(true);
    _error = null;
    
    try {
      print('📍 LocationService: Getting current location...');
      
      // Try to get last known position first (faster)
      Position? lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        print('📍 LocationService: Found last known position: ${lastKnownPosition.latitude}, ${lastKnownPosition.longitude}');
        
        // Only use last known position if it's recent (less than 5 minutes old)
        final ageInMinutes = DateTime.now().difference(lastKnownPosition.timestamp).inMinutes;
        if (ageInMinutes < 5) {
          print('📍 LocationService: Using recent last known position (${ageInMinutes} minutes old)');
          _currentPosition = lastKnownPosition;
          await _resolveAddress();
          _setLoading(false);
          return;
        } else {
          print('📍 LocationService: Last known position is too old (${ageInMinutes} minutes), getting fresh location');
        }
      } else {
        print('📍 LocationService: No last known position available');
      }

      // Get current position with better accuracy settings
      print('📍 LocationService: Requesting fresh location with high accuracy...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 30), // Increased timeout
        forceAndroidLocationManager: false, // Use Google Play Services if available
      );
      
      print('📍 LocationService: Got fresh position: ${position.latitude}, ${position.longitude}');
      print('📍 LocationService: Accuracy: ${position.accuracy}m, Timestamp: ${position.timestamp}');
      
      _currentPosition = position;
      await _resolveAddress();
      
    } catch (e) {
      _error = 'Failed to get current location: ${e.toString()}';
      print('❌ LocationService: Error getting current location: $e');
      
      // Don't silently use fallback coordinates - let the user know there's an issue
      if (_currentPosition == null) {
        print('❌ LocationService: No current position available - location services may not be working');
      }
      
      // Validate if current position is within reasonable Karachi bounds
      if (_currentPosition != null) {
        final lat = _currentPosition!.latitude;
        final lng = _currentPosition!.longitude;
        
        // Karachi bounds: roughly lat 24.7-25.2, lng 66.8-67.5
        if (lat < 24.7 || lat > 25.2 || lng < 66.8 || lng > 67.5) {
          print('⚠️ LocationService: WARNING - Current position seems outside Karachi bounds!');
          print('   Position: ($lat, $lng)');
          print('   Expected: lat 24.7-25.2, lng 66.8-67.5');
          print('   This may cause incorrect route calculations!');
        }
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _resolveAddress() async {
    if (_currentPosition == null) return;
    
    try {
      _currentAddress = await MapboxService.getAddressFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      notifyListeners();
    } catch (e) {
      print('Error resolving address: $e');
      _currentAddress = null;
    }
  }

  Future<String?> getAddressForCoordinates(double latitude, double longitude) async {
    try {
      return await MapboxService.getAddressFromCoordinates(latitude, longitude);
    } catch (e) {
      print('Error getting address for coordinates: $e');
      return null;
    }
  }

  Future<Map<String, double>?> getCoordinatesForAddress(String address) async {
    try {
      return await MapboxService.getCoordinatesFromAddress(address);
    } catch (e) {
      print('Error getting coordinates for address: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyPlaces({double radius = 1000}) async {
    if (_currentPosition == null) return [];
    
    try {
      return await MapboxService.getNearbyPlaces(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        radius: radius,
      );
    } catch (e) {
      print('Error getting nearby places: $e');
      return [];
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
  
  /// Set fallback location (Karachi center) when user explicitly requests it
  void setFallbackLocation() {
    print('📍 LocationService: Setting fallback location (Karachi center)');
    _currentPosition = Position(
      longitude: 67.0011, // Karachi center longitude
      latitude: 24.8607,  // Karachi center latitude
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
    _error = null;
    notifyListeners();
  }
  
  /// Force refresh current location with high accuracy
  Future<void> refreshLocation() async {
    print('🔄 LocationService: Force refreshing location...');
    _setLoading(true);
    _error = null;
    
    try {
      // Force get current position with high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 45), // Longer timeout for better accuracy
        forceAndroidLocationManager: false,
      );
      
      print('📍 LocationService: Refreshed position: ${position.latitude}, ${position.longitude}');
      print('📍 LocationService: Accuracy: ${position.accuracy}m, Timestamp: ${position.timestamp}');
      
      _currentPosition = position;
      await _resolveAddress();
      
    } catch (e) {
      _error = 'Failed to refresh location: ${e.toString()}';
      print('❌ LocationService: Refresh error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Check if current location is in Karachi area
  bool isInKarachiArea() {
    if (_currentPosition == null) return false;
    
    // Karachi bounding box (roughly)
    const double karachiMinLat = 24.7;
    const double karachiMaxLat = 25.2;
    const double karachiMinLng = 66.8;
    const double karachiMaxLng = 67.4;
    
    return _currentPosition!.latitude >= karachiMinLat && 
           _currentPosition!.latitude <= karachiMaxLat &&
           _currentPosition!.longitude >= karachiMinLng && 
           _currentPosition!.longitude <= karachiMaxLng;
  }

  /// Get distance to a location in meters
  double getDistanceTo(double latitude, double longitude) {
    if (_currentPosition == null) return double.infinity;
    
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      latitude,
      longitude,
    );
  }

  /// Get formatted distance string
  String getFormattedDistanceTo(double latitude, double longitude) {
    double distance = getDistanceTo(latitude, longitude);
    
    if (distance < 1000) {
      return '${distance.round()}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }
  
  /// Get detailed location status for debugging
  Map<String, dynamic> getLocationStatus() {
    return {
      'hasPosition': _currentPosition != null,
      'isLoading': _isLoading,
      'hasError': _error != null,
      'permissionGranted': _permissionGranted,
      'position': _currentPosition != null ? {
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'accuracy': _currentPosition!.accuracy,
        'timestamp': _currentPosition!.timestamp.toString(),
        'isInKarachi': isInKarachiArea(),
      } : null,
      'error': _error,
      'address': _currentAddress,
    };
  }
  
  /// Print detailed location status to console for debugging
  void printLocationStatus() {
    final status = getLocationStatus();
    print('📍 LocationService: Status Report');
    print('   Has Position: ${status['hasPosition']}');
    print('   Is Loading: ${status['isLoading']}');
    print('   Has Error: ${status['hasError']}');
    print('   Permission Granted: ${status['permissionGranted']}');
    
    if (status['position'] != null) {
      final pos = status['position'] as Map<String, dynamic>;
      print('   Position: ${pos['latitude']}, ${pos['longitude']}');
      print('   Accuracy: ${pos['accuracy']}m');
      print('   Timestamp: ${pos['timestamp']}');
      print('   In Karachi: ${pos['isInKarachi']}');
    }
    
    if (status['error'] != null) {
      print('   Error: ${status['error']}');
    }
    
    if (status['address'] != null) {
      print('   Address: ${status['address']}');
    }
  }
} 