import 'dart:math';

/// Utility class for calculating distances, travel times, and formatting distance strings
class DistanceCalculator {
  /// Earth's radius in meters
  static const double _earthRadius = 6371000.0; // 6,371 km

  /// Calculate the great circle distance between two points using the Haversine formula
  /// Returns distance in meters
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Convert degrees to radians
    final lat1Rad = _degreesToRadians(lat1);
    final lon1Rad = _degreesToRadians(lon1);
    final lat2Rad = _degreesToRadians(lat2);
    final lon2Rad = _degreesToRadians(lon2);

    // Haversine formula
    final dLat = lat2Rad - lat1Rad;
    final dLon = lon2Rad - lon1Rad;
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
              cos(lat1Rad) * cos(lat2Rad) *
              sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return _earthRadius * c;
  }

  /// Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180.0);
  }

  /// Format distance in a human-readable format
  /// Returns formatted string like "1.2km" or "500m"
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 0) {
      return 'Invalid distance';
    }
    
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km';
    }
  }

  /// Calculate walking time in minutes
  /// Assumes average walking speed of 5 km/h (1.39 m/s)
  static int calculateWalkingTimeMinutes(double distanceInMeters) {
    const double walkingSpeedMps = 1.39; // meters per second (5 km/h)
    final timeInSeconds = distanceInMeters / walkingSpeedMps;
    return (timeInSeconds / 60).round();
  }

  /// Calculate driving time in minutes
  /// Assumes average driving speed of 30 km/h in city traffic
  static int calculateDrivingTimeMinutes(double distanceInMeters) {
    const double drivingSpeedMps = 8.33; // meters per second (30 km/h)
    final timeInSeconds = distanceInMeters / drivingSpeedMps;
    return (timeInSeconds / 60).round();
  }

  /// Calculate cycling time in minutes
  /// Assumes average cycling speed of 15 km/h
  static int calculateCyclingTimeMinutes(double distanceInMeters) {
    const double cyclingSpeedMps = 4.17; // meters per second (15 km/h)
    final timeInSeconds = distanceInMeters / cyclingSpeedMps;
    return (timeInSeconds / 60).round();
  }

  /// Calculate public transport time in minutes
  /// Includes walking to/from stops and waiting time
  static int calculatePublicTransportTimeMinutes(double totalDistanceInMeters) {
    // Base walking time to/from stops (assume 200m each way)
    const double walkingToStopDistance = 200.0;
    const double walkingFromStopDistance = 200.0;
    
    final walkingTime = calculateWalkingTimeMinutes(walkingToStopDistance + walkingFromStopDistance);
    
    // Bus travel time (assume 25 km/h average speed)
    const double busSpeedMps = 6.94; // meters per second (25 km/h)
    final busTimeInSeconds = totalDistanceInMeters / busSpeedMps;
    final busTimeMinutes = (busTimeInSeconds / 60).round();
    
    // Add waiting time (assume 5 minutes average)
    const int waitingTimeMinutes = 5;
    
    return walkingTime + busTimeMinutes + waitingTimeMinutes;
  }

  /// Calculate journey time with Bykea/Careem
  /// Assumes average speed of 25 km/h for bike rides
  static int calculateJourneyTimeWithBykea(double distanceInMeters) {
    const double bykeaSpeedMps = 6.94; // meters per second (25 km/h)
    final timeInSeconds = distanceInMeters / bykeaSpeedMps;
    return (timeInSeconds / 60).round();
  }

  /// Calculate rickshaw time in minutes
  /// Assumes average speed of 20 km/h for rickshaws
  static int calculateRickshawTimeMinutes(double distanceInMeters) {
    const double rickshawSpeedMps = 5.56; // meters per second (20 km/h)
    final timeInSeconds = distanceInMeters / rickshawSpeedMps;
    return (timeInSeconds / 60).round();
  }

  /// Calculate total journey time including multiple transport modes
  static int calculateTotalJourneyTime({
    required double walkingDistanceToStart,
    required double busDistance,
    required double walkingDistanceFromEnd,
    String transportModeToStart = 'walking',
    String transportModeFromEnd = 'walking',
  }) {
    int timeToStart = 0;
    int timeFromEnd = 0;
    
    // Calculate time to boarding stop
    switch (transportModeToStart) {
      case 'walking':
        timeToStart = calculateWalkingTimeMinutes(walkingDistanceToStart);
        break;
      case 'rickshaw':
        timeToStart = calculateRickshawTimeMinutes(walkingDistanceToStart);
        break;
      case 'bykea':
      case 'careem':
        timeToStart = calculateJourneyTimeWithBykea(walkingDistanceToStart);
        break;
      default:
        timeToStart = calculateWalkingTimeMinutes(walkingDistanceToStart);
    }
    
    // Calculate time from destination stop
    switch (transportModeFromEnd) {
      case 'walking':
        timeFromEnd = calculateWalkingTimeMinutes(walkingDistanceFromEnd);
        break;
      case 'rickshaw':
        timeFromEnd = calculateRickshawTimeMinutes(walkingDistanceFromEnd);
        break;
      case 'bykea':
      case 'careem':
        timeFromEnd = calculateJourneyTimeWithBykea(walkingDistanceFromEnd);
        break;
      default:
        timeFromEnd = calculateWalkingTimeMinutes(walkingDistanceFromEnd);
    }
    
    // Bus travel time (assume 25 km/h average speed)
    const double busSpeedMps = 6.94; // meters per second (25 km/h)
    final busTimeInSeconds = busDistance / busSpeedMps;
    final busTimeMinutes = (busTimeInSeconds / 60).round();
    
    // Add waiting time (assume 5 minutes average)
    const int waitingTimeMinutes = 5;
    
    return timeToStart + busTimeMinutes + waitingTimeMinutes + timeFromEnd;
  }

  /// Check if two points are very close (within 50 meters)
  static bool isVeryClose(double lat1, double lon1, double lat2, double lon2) {
    final distance = calculateDistance(lat1, lon1, lat2, lon2);
    return distance <= 50.0; // 50 meters
  }

  /// Check if two points are close (within 200 meters)
  static bool isClose(double lat1, double lon1, double lat2, double lon2) {
    final distance = calculateDistance(lat1, lon1, lat2, lon2);
    return distance <= 200.0; // 200 meters
  }

  /// Check if two points are moderately close (within 500 meters)
  static bool isModeratelyClose(double lat1, double lon1, double lat2, double lon2) {
    final distance = calculateDistance(lat1, lon1, lat2, lon2);
    return distance <= 500.0; // 500 meters
  }

  /// Calculate the midpoint between two coordinates
  static Map<String, double> calculateMidpoint(double lat1, double lon1, double lat2, double lon2) {
    final lat1Rad = _degreesToRadians(lat1);
    final lon1Rad = _degreesToRadians(lon1);
    final lat2Rad = _degreesToRadians(lat2);
    final lon2Rad = _degreesToRadians(lon2);

    final dLon = lon2Rad - lon1Rad;
    final Bx = cos(lat2Rad) * cos(dLon);
    final By = cos(lat2Rad) * sin(dLon);

    final midLat = atan2(
      sin(lat1Rad) + sin(lat2Rad),
      sqrt((cos(lat1Rad) + Bx) * (cos(lat1Rad) + Bx) + By * By)
    );

    final midLon = lon1Rad + atan2(By, cos(lat1Rad) + Bx);

    return {
      'latitude': _radiansToDegrees(midLat),
      'longitude': _radiansToDegrees(midLon),
    };
  }

  /// Convert radians to degrees
  static double _radiansToDegrees(double radians) {
    return radians * (180.0 / pi);
  }

  /// Calculate bearing between two points
  static double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final lat1Rad = _degreesToRadians(lat1);
    final lon1Rad = _degreesToRadians(lon1);
    final lat2Rad = _degreesToRadians(lat2);
    final lon2Rad = _degreesToRadians(lon2);

    final dLon = lon2Rad - lon1Rad;

    final y = sin(dLon) * cos(lat2Rad);
    final x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLon);

    final bearing = atan2(y, x);
    return _radiansToDegrees(bearing);
  }

  /// Validate if coordinates are within reasonable bounds
  static bool isValidCoordinate(double lat, double lon) {
    return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180;
  }

  /// Calculate distance with road network adjustment factor
  /// This provides a rough estimate of road distance vs straight-line distance
  static double calculateRoadDistance(double lat1, double lon1, double lat2, double lon2) {
    final straightLineDistance = calculateDistance(lat1, lon1, lat2, lon2);
    
    // Apply road network adjustment factor (typically 1.1 to 1.4 for urban areas)
    const double roadNetworkFactor = 1.3;
    
    return straightLineDistance * roadNetworkFactor;
  }

  /// Calculate Bykea fare based on distance
  /// Returns fare in PKR (Pakistani Rupees)
  static int calculateBykeaFare(double distanceInMeters) {
    const double baseFare = 50.0; // Base fare in PKR
    const double perKmRate = 15.0; // Rate per kilometer in PKR
    
    final distanceInKm = distanceInMeters / 1000.0;
    
    if (distanceInKm <= 2.0) {
      return baseFare.round(); // Base fare for first 2km
    } else {
      final additionalKm = distanceInKm - 2.0;
      final additionalFare = additionalKm * perKmRate;
      return (baseFare + additionalFare).round();
    }
  }

  /// Calculate Rickshaw fare based on distance
  /// Returns fare in PKR (Pakistani Rupees)
  static int calculateRickshawFare(double distanceInMeters) {
    const double baseFare = 100.0; // Base fare in PKR for 3km
    const double perKmRate = 20.0; // Rate per kilometer in PKR after 3km
    
    final distanceInKm = distanceInMeters / 1000.0;
    
    if (distanceInKm <= 3.0) {
      return baseFare.round(); // Base fare for first 3km
    } else {
      final additionalKm = distanceInKm - 3.0;
      final additionalFare = additionalKm * perKmRate;
      return (baseFare + additionalFare).round();
    }
  }
} 