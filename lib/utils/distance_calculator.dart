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
  
  /// Google Maps-like walking time calculation
  /// Considers: pedestrian infrastructure, traffic lights, road crossings, time of day
  static int calculateWalkingTimeMinutes(double distanceInMeters) {
    // Base walking speed: 5.0 km/h (Google Maps standard)
    const double baseWalkingSpeedKmh = 5.0;
    const double baseWalkingSpeedMs = baseWalkingSpeedKmh * 1000 / 3600;
    
    // Get current time for time-of-day adjustments
    final now = DateTime.now();
    final hour = now.hour;
    
    // Time-of-day factors (based on Google Maps patterns)
    double timeOfDayFactor = 1.0;
    if (hour >= 7 && hour <= 9) {
      // Morning rush hour: slower due to crowds
      timeOfDayFactor = 1.15;
    } else if (hour >= 17 && hour <= 19) {
      // Evening rush hour: slower due to crowds
      timeOfDayFactor = 1.15;
    } else if (hour >= 22 || hour <= 6) {
      // Night time: faster due to less pedestrian traffic
      timeOfDayFactor = 0.9;
    }
    
    // Distance-based adjustments (Google Maps logic)
    double distanceFactor = 1.0;
    if (distanceInMeters > 2000) {
      // Long distances: fatigue factor
      distanceFactor = 1.1;
    } else if (distanceInMeters < 200) {
      // Short distances: faster due to motivation
      distanceFactor = 0.95;
    }
    
    // Urban infrastructure factor (Karachi-specific)
    const double urbanFactor = 1.25; // Traffic lights, crossings, obstacles
    
    // Calculate base time
    double baseTimeSeconds = distanceInMeters / baseWalkingSpeedMs;
    
    // Apply all factors
    double adjustedTimeSeconds = baseTimeSeconds * timeOfDayFactor * distanceFactor * urbanFactor;
    
    return (adjustedTimeSeconds / 60).round();
  }

  /// Google Maps-like public transport time calculation
  /// Considers: schedules, traffic, transfers, waiting time
  static int calculatePublicTransportTimeMinutes({
    required double distanceInMeters,
    required bool isBRT,
    required bool requiresTransfer,
    DateTime? departureTime,
  }) {
    // Use current time if not specified
    final time = departureTime ?? DateTime.now();
    final hour = time.hour;
    final isWeekend = time.weekday == DateTime.saturday || time.weekday == DateTime.sunday;
    
    // Base speeds (Google Maps standards for Karachi)
    double baseSpeedKmh;
    if (isBRT) {
      baseSpeedKmh = 60.0; // BRT average speed (dedicated lanes, fewer stops)
    } else {
      baseSpeedKmh = 35.0; // Regular bus average speed
    }
    
    double baseSpeedMs = baseSpeedKmh * 1000 / 3600;
    
    // Time-of-day traffic factors (Google Maps patterns)
    double trafficFactor = 1.0;
    if (hour >= 7 && hour <= 9) {
      // Morning rush hour
      trafficFactor = isWeekend ? 1.02 : 1.08;
    } else if (hour >= 17 && hour <= 19) {
      // Evening rush hour
      trafficFactor = isWeekend ? 1.02 : 1.08;
    } else if (hour >= 10 && hour <= 16) {
      // Mid-day: moderate traffic
      trafficFactor = 1.05;
    } else if (hour >= 20 || hour <= 6) {
      // Night: less traffic
      trafficFactor = 0.98;
    }
    
    // Distance-based adjustments
    double distanceFactor = 1.0;
    if (distanceInMeters > 10000) {
      // Long distances: more stops, more delays
      distanceFactor = 1.05;
    } else if (distanceInMeters < 2000) {
      // Short distances: fewer stops
      distanceFactor = 0.98;
    }
    
    // Calculate base travel time
    double baseTimeSeconds = distanceInMeters / baseSpeedMs;
    double adjustedTimeSeconds = baseTimeSeconds * trafficFactor * distanceFactor;
    
    // Add waiting time (Google Maps standard)
    int waitingTimeMinutes = 0;
    if (isBRT) {
      // BRT has more frequent service
      waitingTimeMinutes = 2;
    } else {
      // Regular bus service
      waitingTimeMinutes = 5;
    }
    
    // Add transfer time if needed
    int transferTimeMinutes = 0;
    if (requiresTransfer) {
      transferTimeMinutes = 5; // Google Maps standard for transfers
    }
    
    return (adjustedTimeSeconds / 60).round() + waitingTimeMinutes + transferTimeMinutes;
  }

  /// Google Maps-like driving time calculation
  /// Considers: traffic, road conditions, time of day, vehicle type
  static int calculateDrivingTimeMinutes({
    required double distanceInMeters,
    required String vehicleType, // 'car', 'motorcycle', 'rickshaw'
    DateTime? departureTime,
  }) {
    final time = departureTime ?? DateTime.now();
    final hour = time.hour;
    final isWeekend = time.weekday == DateTime.saturday || time.weekday == DateTime.sunday;
    
    // Base speeds by vehicle type (Google Maps standards for Karachi)
    double baseSpeedKmh;
    switch (vehicleType.toLowerCase()) {
      case 'car':
        baseSpeedKmh = 45.0;
        break;
      case 'motorcycle':
      case 'bykea':
        baseSpeedKmh = 50.0;
        break;
      case 'rickshaw':
        baseSpeedKmh = 35.0;
        break;
      default:
        baseSpeedKmh = 40.0;
    }
    
    double baseSpeedMs = baseSpeedKmh * 1000 / 3600;
    
    // Time-of-day traffic factors (Google Maps patterns)
    double trafficFactor = 1.0;
    if (hour >= 7 && hour <= 9) {
      // Morning rush hour
      trafficFactor = isWeekend ? 1.1 : 1.4;
    } else if (hour >= 17 && hour <= 19) {
      // Evening rush hour
      trafficFactor = isWeekend ? 1.1 : 1.4;
    } else if (hour >= 10 && hour <= 16) {
      // Mid-day: moderate traffic
      trafficFactor = 1.2;
    } else if (hour >= 20 || hour <= 6) {
      // Night: less traffic
      trafficFactor = 0.9;
    }
    
    // Distance-based adjustments
    double distanceFactor = 1.0;
    if (distanceInMeters > 15000) {
      // Long distances: highway speeds
      distanceFactor = 0.9;
    } else if (distanceInMeters < 3000) {
      // Short distances: more stops, traffic lights
      distanceFactor = 1.3;
    }
    
    // Calculate travel time
    double baseTimeSeconds = distanceInMeters / baseSpeedMs;
    double adjustedTimeSeconds = baseTimeSeconds * trafficFactor * distanceFactor;
    
    return (adjustedTimeSeconds / 60).round();
  }

  /// Google Maps-like total journey time calculation
  /// Combines walking + public transport + transfers
  static int calculateTotalJourneyTime({
    required double walkingDistanceToStart,
    required double publicTransportDistance,
    required double walkingDistanceFromEnd,
    required bool isBRT,
    required bool requiresTransfer,
    DateTime? departureTime,
  }) {
    // Walking to start
    final walkingTime1 = calculateWalkingTimeMinutes(walkingDistanceToStart);
    
    // Public transport journey
    final transportTime = calculatePublicTransportTimeMinutes(
      distanceInMeters: publicTransportDistance,
      isBRT: isBRT,
      requiresTransfer: requiresTransfer,
      departureTime: departureTime,
    );
    
    // Walking from end
    final walkingTime2 = calculateWalkingTimeMinutes(walkingDistanceFromEnd);
    
    // Total time
    int totalTime = walkingTime1 + transportTime + walkingTime2;
    
    // Additional buffer for real-world factors (Google Maps approach)
    totalTime += 2; // 2-minute buffer for unexpected delays
    
    return totalTime;
  }

  /// Calculate total journey time including Bykea to bus stop + bus journey + final leg to destination
  /// This is the main time calculation for the app
  static int calculateJourneyTimeWithBykea({
    required double distanceToBusStop,
    required double busJourneyDistance,
    required double distanceFromBusStopToDestination,
    required bool requiresTransfer,
    DateTime? departureTime,
  }) {
    // Bykea time to bus stop
    final bykeaTime = calculateDrivingTimeMinutes(
      distanceInMeters: distanceToBusStop,
      vehicleType: 'bykea',
      departureTime: departureTime,
    );
    
    // Bus journey time
    final busTime = calculatePublicTransportTimeMinutes(
      distanceInMeters: busJourneyDistance,
      isBRT: true,
      requiresTransfer: requiresTransfer,
      departureTime: departureTime,
    );
    
    // Final leg time (walking or short ride to destination)
    int finalLegTime;
    if (distanceFromBusStopToDestination < 500) {
      // Short distance: walking
      finalLegTime = calculateWalkingTimeMinutes(distanceFromBusStopToDestination);
    } else if (distanceFromBusStopToDestination < 2000) {
      // Medium distance: rickshaw
      finalLegTime = calculateDrivingTimeMinutes(
        distanceInMeters: distanceFromBusStopToDestination,
        vehicleType: 'rickshaw',
        departureTime: departureTime,
      );
    } else {
      // Long distance: Bykea
      finalLegTime = calculateDrivingTimeMinutes(
        distanceInMeters: distanceFromBusStopToDestination,
        vehicleType: 'bykea',
        departureTime: departureTime,
      );
    }
    
    // Total journey time: Bykea to bus + Bus journey + Final leg to destination
    return bykeaTime + busTime + finalLegTime;
  }

  /// Legacy methods for backward compatibility
  @Deprecated('Use calculateWalkingTimeMinutes instead')
  static int calculateBusTimeMinutes(double distanceInMeters) {
    return calculatePublicTransportTimeMinutes(
      distanceInMeters: distanceInMeters,
      isBRT: true,
      requiresTransfer: false,
    );
  }

  @Deprecated('Use calculateDrivingTimeMinutes instead')
  static int calculateRickshawTimeMinutes(double distanceInMeters) {
    return calculateDrivingTimeMinutes(
      distanceInMeters: distanceInMeters,
      vehicleType: 'rickshaw',
    );
  }

  @Deprecated('Use calculateDrivingTimeMinutes instead')
  static int calculateCarTimeMinutes(double distanceInMeters) {
    return calculateDrivingTimeMinutes(
      distanceInMeters: distanceInMeters,
      vehicleType: 'car',
    );
  }
}
