import 'dart:math';

class DistanceCalculator {
  /// Calculate distance between two points using Haversine formula
  /// Returns distance in meters
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }
  
  /// Format distance for display
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }
  
  /// Calculate walking time estimate (average walking speed: 5 km/h)
  static int calculateWalkingTimeMinutes(double distanceInMeters) {
    const double walkingSpeedKmh = 5.0;
    const double walkingSpeedMs = walkingSpeedKmh * 1000 / 3600; // m/s
    
    final double timeInSeconds = distanceInMeters / walkingSpeedMs;
    return (timeInSeconds / 60).round();
  }
  
  /// Calculate bus travel time estimate (average bus speed: 25 km/h)
  static int calculateBusTimeMinutes(double distanceInMeters) {
    const double busSpeedKmh = 25.0;
    const double busSpeedMs = busSpeedKmh * 1000 / 3600; // m/s
    
    final double timeInSeconds = distanceInMeters / busSpeedMs;
    return (timeInSeconds / 60).round();
  }
}
