import 'package:flutter/foundation.dart';
import '../models/stop.dart';
import '../models/route.dart';
import '../utils/distance_calculator.dart';
import 'data_service.dart';
import 'mapbox_service.dart';
import 'mapbox_directions_service.dart';

class RouteFinder extends ChangeNotifier {
  final DataService _dataService;
  
  RouteFinder(this._dataService);
  
  /// Find the best journey from user location to destination with Mapbox integration
  Future<Journey?> findBestRoute({
    required double userLat,
    required double userLng,
    required double destLat,
    required double destLng,
  }) async {
    await _dataService.loadBRTData();
    
    final stops = _dataService.stops;
    if (stops.isEmpty) return null;
    
    print('🚌 RouteFinder: Starting route search from (${userLat.toStringAsFixed(4)}, ${userLng.toStringAsFixed(4)}) to (${destLat.toStringAsFixed(4)}, ${destLng.toStringAsFixed(4)})');
    
    // Debug: Check if destination might be Fast University
    if (destLat >= 24.85 && destLat <= 24.87 && destLng >= 67.26 && destLng <= 67.27) {
      print('🎓 RouteFinder: Destination coordinates suggest Fast University area');
    }
    
    // Debug: Show user's current location context
    print('📍 RouteFinder: User is at coordinates (${userLat.toStringAsFixed(6)}, ${userLng.toStringAsFixed(6)})');
    print('🎯 RouteFinder: Destination is at coordinates (${destLat.toStringAsFixed(6)}, ${destLng.toStringAsFixed(6)})');
    
    // Calculate direct distance between user and destination
    final directDistance = DistanceCalculator.calculateDistance(userLat, userLng, destLat, destLng);
    print('📏 RouteFinder: Direct distance from user to destination: ${DistanceCalculator.formatDistance(directDistance)}');
    
    // Test distance calculation with known coordinates
    final testDistance = DistanceCalculator.calculateDistance(24.8607, 67.0011, 24.8571541, 67.2645918);
    print('🧪 RouteFinder: Test distance (Karachi center to Fast University): ${DistanceCalculator.formatDistance(testDistance)}');
    
    // Check if user location seems reasonable (within Karachi bounds)
    if (userLat < 24.7 || userLat > 25.2 || userLng < 66.8 || userLng > 67.5) {
      print('⚠️ RouteFinder: WARNING - User location seems outside Karachi bounds!');
      print('   Expected: lat 24.7-25.2, lng 66.8-67.5');
      print('   Actual: lat $userLat, lng $userLng');
    }
    
    // Check if destination is at a bus stop (within 50 meters)
    final destinationStop = _findExactBusStop(destLat, destLng, stops);
    if (destinationStop != null) {
      print('🎯 RouteFinder: Destination is at bus stop: ${destinationStop.name} (${destinationStop.routes.join(', ')})');
      
      // Find best boarding stop for user to reach this exact destination stop
      final bestBoardingStop = _findBestBoardingStop(
        userLat,
        userLng,
        destinationStop,
        stops,
      );
      
      if (bestBoardingStop != null && bestBoardingStop.id != destinationStop.id) {
        print('🚏 RouteFinder: Best boarding stop: ${bestBoardingStop.name} (${bestBoardingStop.routes.join(', ')})');
        
        // Create journey to the exact destination stop
        final journey = await _createEnhancedJourney(
          userLat: userLat,
          userLng: userLng,
          destLat: destLat,
          destLng: destLng,
          boardingStop: bestBoardingStop,
          destinationStop: destinationStop,
        );
        
        if (journey != null) {
          print('✅ RouteFinder: Journey created successfully to exact destination stop');
          print('   - Boarding: ${journey.startStop.name}');
          print('   - Destination: ${journey.endStop.name} (EXACT STOP)');
          print('   - Routes: ${journey.routes.map((r) => r.name).join(', ')}');
          print('   - Total distance: ${DistanceCalculator.formatDistance(journey.totalDistance)}');
        }
        
        return journey;
      } else if (bestBoardingStop != null && bestBoardingStop.id == destinationStop.id) {
        print('🚶 RouteFinder: User is already at destination stop. Suggesting walking.');
        return _createWalkingOnlyJourney(
          userLat: userLat,
          userLng: userLng,
          destLat: destLat,
          destLng: destLng,
          destinationStop: destinationStop,
        );
      }
    }
    
    // If destination is not at a bus stop, find nearest stop to destination
    // Special handling for Fast University searches
    Stop? nearestToDestination;
    
    // Check if this might be a Fast University search
    if (destLat >= 24.85 && destLat <= 24.87 && destLng >= 67.26 && destLng <= 67.27) {
      print('🎓 RouteFinder: Detected Fast University area search');
      nearestToDestination = _findFastUniversityStop(destLat, destLng, stops);
    }
    
    // If no special handling found, use regular nearest stop logic
    if (nearestToDestination == null) {
      nearestToDestination = _findNearestStop(destLat, destLng, stops);
    }
    
    if (nearestToDestination == null) return null;
    
    print('🎯 RouteFinder: Nearest stop to destination: ${nearestToDestination.name} (${nearestToDestination.routes.join(', ')})');
    
    // Find best boarding stop for user
    final bestBoardingStop = _findBestBoardingStop(
      userLat,
      userLng,
      nearestToDestination,
      stops,
    );
    if (bestBoardingStop == null) {
      print('🚶 RouteFinder: No suitable bus route found. Destination may be too close for bus travel.');
      // Create a walking-only journey
      return _createWalkingOnlyJourney(
        userLat: userLat,
        userLng: userLng,
        destLat: destLat,
        destLng: destLng,
        destinationStop: nearestToDestination,
      );
    }
    
    print('🚏 RouteFinder: Best boarding stop: ${bestBoardingStop.name} (${bestBoardingStop.routes.join(', ')})');
    
    // Calculate journey details with Mapbox integration
    final journey = await _createEnhancedJourney(
      userLat: userLat,
      userLng: userLng,
      destLat: destLat,
      destLng: destLng,
      boardingStop: bestBoardingStop,
      destinationStop: nearestToDestination,
    );
    
    if (journey != null) {
      print('✅ RouteFinder: Journey created successfully');
      print('   - Boarding: ${journey.startStop.name}');
      print('   - Destination: ${journey.endStop.name}');
      print('   - Routes: ${journey.routes.map((r) => r.name).join(', ')}');
      print('   - Total distance: ${DistanceCalculator.formatDistance(journey.totalDistance)}');
    }
    
    return journey;
  }
  
  /// Find the best route with multiple options using Mapbox
  Future<List<Journey>> findMultipleRoutes({
    required double userLat,
    required double userLng,
    required double destLat,
    required double destLng,
    int maxRoutes = 3,
  }) async {
    await _dataService.loadBRTData();
    
    final stops = _dataService.stops;
    if (stops.isEmpty) return [];
    
    // Check if destination is at a bus stop (within 50 meters)
    final destinationStop = _findExactBusStop(destLat, destLng, stops);
    if (destinationStop != null) {
      print('🎯 RouteFinder: Destination is at bus stop: ${destinationStop.name} (${destinationStop.routes.join(', ')})');
      
      // Find all viable boarding stops that can reach this exact destination stop
      final viableStops = stops.where((stop) {
        return stop.routes.any((route) => destinationStop.routes.contains(route));
      }).toList();
      
      if (viableStops.isEmpty) {
        // If no direct route, find transfer options
        final transferStop = _findTransferRoute(userLat, userLng, destinationStop, stops);
        if (transferStop != null) {
          final journey = await _createEnhancedJourney(
            userLat: userLat,
            userLng: userLng,
            destLat: destLat,
            destLng: destLng,
            boardingStop: transferStop,
            destinationStop: destinationStop,
          );
          return journey != null ? [journey] : [];
        }
        return [];
      }
      
      // Get multiple route options to the exact destination stop
      final routeOptions = _getMultipleRouteOptions(
        userLat, userLng, destinationStop, viableStops, maxRoutes
      );
      
      List<Journey> journeys = [];
      
      for (final option in routeOptions) {
        final journey = await _createEnhancedJourney(
          userLat: userLat,
          userLng: userLng,
          destLat: destLat,
          destLng: destLng,
          boardingStop: option['stop'] as Stop,
          destinationStop: destinationStop,
        );
        
        if (journey != null) {
          journeys.add(journey);
        }
      }
      
      // Sort journeys by total time
      journeys.sort((a, b) {
        final timeA = _calculateTotalJourneyTime(a);
        final timeB = _calculateTotalJourneyTime(b);
        return timeA.compareTo(timeB);
      });
      
      return journeys.take(maxRoutes).toList();
    }
    
    // If destination is not at a bus stop, find nearest stop to destination
    final nearestToDestination = _findNearestStop(destLat, destLng, stops);
    if (nearestToDestination == null) return [];
    
    // Find all viable boarding stops with route-based prioritization
    final viableStops = stops.where((stop) {
      return stop.routes.any((route) => nearestToDestination.routes.contains(route));
    }).toList();
    
    if (viableStops.isEmpty) {
      // If no direct route, find transfer options
      final transferStop = _findTransferRoute(userLat, userLng, nearestToDestination, stops);
      if (transferStop != null) {
        final journey = await _createEnhancedJourney(
          userLat: userLat,
          userLng: userLng,
          destLat: destLat,
          destLng: destLng,
          boardingStop: transferStop,
          destinationStop: nearestToDestination,
        );
        return journey != null ? [journey] : [];
      }
      return [];
    }
    
    // Get multiple route options using the new destination-oriented logic
    final routeOptions = _getMultipleRouteOptions(
      userLat, userLng, nearestToDestination, viableStops, maxRoutes
    );
    
    List<Journey> journeys = [];
    
    for (final option in routeOptions) {
      final journey = await _createEnhancedJourney(
        userLat: userLat,
        userLng: userLng,
        destLat: destLat,
        destLng: destLng,
        boardingStop: option['stop'] as Stop,
        destinationStop: nearestToDestination,
      );
      
      if (journey != null) {
        journeys.add(journey);
      }
    }
    
    // Sort journeys by total time
    journeys.sort((a, b) {
      final timeA = _calculateTotalJourneyTime(a);
      final timeB = _calculateTotalJourneyTime(b);
      return timeA.compareTo(timeB);
    });
    
    return journeys.take(maxRoutes).toList();
  }
  
  List<Map<String, dynamic>> _getMultipleRouteOptions(
    double userLat,
    double userLng,
    Stop destinationStop,
    List<Stop> viableStops,
    int maxOptions,
  ) {
    // Group stops by their routes to the destination
    final Map<String, List<Stop>> routeGroups = {};
    
    for (final stop in viableStops) {
      final commonRoutes = stop.routes
          .where((route) => destinationStop.routes.contains(route))
          .toList();
      
      for (final route in commonRoutes) {
        routeGroups.putIfAbsent(route, () => []).add(stop);
      }
    }
    
    // Use the same priority-based approach as single route finding
    final List<Map<String, dynamic>> allRouteOptions = [];
    
    // PRIORITY 1: Find routes that go directly to destination or very close to it
    final directRouteOptions = _findDirectRouteOptions(
      userLat, userLng, destinationStop, routeGroups
    );
    allRouteOptions.addAll(directRouteOptions);
    
    // PRIORITY 2: Find the closest stop from user's location that leads to closest stop to destination
    final proximityRouteOptions = _findProximityBasedRouteOptions(
      userLat, userLng, destinationStop, routeGroups
    );
    allRouteOptions.addAll(proximityRouteOptions);
    
    // Sort by priority and score
    allRouteOptions.sort((a, b) {
      // First sort by priority (exact_destination > very_close > close > proximity)
      final priorityA = a['priority'] as String;
      final priorityB = b['priority'] as String;
      
      if (priorityA != priorityB) {
        if (priorityA == 'exact_destination') return -1;
        if (priorityB == 'exact_destination') return 1;
        if (priorityA == 'very_close') return -1;
        if (priorityB == 'very_close') return 1;
        if (priorityA == 'close') return -1;
        if (priorityB == 'close') return 1;
      }
      
      // Then sort by score within same priority
      return a['score'].compareTo(b['score']);
    });
    
    // Remove duplicates (same route) and return top options
    final Map<String, Map<String, dynamic>> uniqueRoutes = {};
    for (final option in allRouteOptions) {
      final routeName = option['route'] as String;
      if (!uniqueRoutes.containsKey(routeName)) {
        uniqueRoutes[routeName] = option;
      }
    }
    
    return uniqueRoutes.values.take(maxOptions).toList();
  }
  
  /// Check if destination is exactly at a bus stop (within 100 meters)
  Stop? _findExactBusStop(double lat, double lng, List<Stop> stops) {
    if (stops.isEmpty) return null;
    
    const double exactStopThreshold = 100; // 100 meters - destination is at this bus stop
    
    for (final stop in stops) {
      try {
        final distance = DistanceCalculator.calculateDistance(
          lat,
          lng,
          stop.lat,
          stop.lng,
        );
        
        // Debug: Print distance to Fast University specifically
        if (stop.name.toLowerCase().contains('fast') || stop.name.toLowerCase().contains('university')) {
          print('🎓 RouteFinder: Distance to ${stop.name}: ${DistanceCalculator.formatDistance(distance)}');
        }
        
        if (distance <= exactStopThreshold) {
          print('🎯 RouteFinder: Destination is at bus stop ${stop.name} (distance: ${DistanceCalculator.formatDistance(distance)})');
          return stop;
        }
      } catch (e) {
        // Skip invalid stop data
        continue;
      }
    }
    
    return null;
  }
  
  /// Get more accurate road network distance using Mapbox when possible
  Future<double> _getAccurateDistance(double lat1, double lng1, double lat2, double lng2) async {
    try {
      // Try to get road network distance from Mapbox
      final routeInfo = await MapboxDirectionsService.getRouteInfo(
        startLat: lat1,
        startLng: lng1,
        endLat: lat2,
        endLng: lng2,
        routeType: MapboxRouteType.driving,
      );
      
      if (routeInfo != null && routeInfo.distance > 0) {
        print('🗺️ RouteFinder: Using Mapbox road distance: ${DistanceCalculator.formatDistance(routeInfo.distance)}');
        return routeInfo.distance;
      }
    } catch (e) {
      print('⚠️ RouteFinder: Mapbox distance calculation failed, using straight-line: $e');
    }
    
    // Fallback to straight-line distance
    final straightLineDistance = DistanceCalculator.calculateDistance(lat1, lng1, lat2, lng2);
    print('📏 RouteFinder: Using straight-line distance: ${DistanceCalculator.formatDistance(straightLineDistance)}');
    return straightLineDistance;
  }

  /// Special handling for Fast University searches
  Stop? _findFastUniversityStop(double lat, double lng, List<Stop> stops) {
    // Look for Fast University stop specifically
    final fastUniversityStop = stops.where((stop) => 
      stop.name.toLowerCase().contains('fast') && 
      stop.name.toLowerCase().contains('university')
    ).firstOrNull;
    
    if (fastUniversityStop != null) {
      final distance = DistanceCalculator.calculateDistance(
        lat, lng, fastUniversityStop.lat, fastUniversityStop.lng
      );
      
      print('🎓 RouteFinder: Found Fast University stop: ${fastUniversityStop.name}');
      print('🎓 RouteFinder: Distance to Fast University: ${DistanceCalculator.formatDistance(distance)}');
      
      // If user is within 5km of Fast University, prioritize it
      if (distance <= 5000) {
        print('🎓 RouteFinder: User is within 5km of Fast University, prioritizing it');
        return fastUniversityStop;
      }
    }
    
    return null;
  }

  Stop? _findNearestStop(double lat, double lng, List<Stop> stops) {
    if (stops.isEmpty) return null;
    
    Stop? nearest;
    double minDistance = double.infinity;
    
    // Debug: Check if this is for Fast University area
    final isFastUniversityArea = (lat >= 24.85 && lat <= 24.87 && lng >= 67.26 && lng <= 67.27);
    if (isFastUniversityArea) {
      print('🎓 RouteFinder: Searching for nearest stop in Fast University area');
      print('🎓 RouteFinder: User location: ($lat, $lng)');
    }
    
    for (final stop in stops) {
      try {
        final distance = DistanceCalculator.calculateDistance(
          lat,
          lng,
          stop.lat,
          stop.lng,
        );
        
        // Debug: Show distances for Fast University and nearby stops
        if (isFastUniversityArea || 
            stop.name.toLowerCase().contains('fast') || 
            stop.name.toLowerCase().contains('university') ||
            stop.name.toLowerCase().contains('manzil') ||
            stop.name.toLowerCase().contains('quaidabad')) {
          print('🎓 RouteFinder: Distance to ${stop.name}: ${DistanceCalculator.formatDistance(distance)} (${stop.lat}, ${stop.lng})');
        }
        
        // For Fast University area, prioritize stops that are actually closer
        if (isFastUniversityArea) {
          // If this is Fast University stop, give it priority if it's reasonably close
          if (stop.name.toLowerCase().contains('fast') && distance <= 2000) {
            print('🎓 RouteFinder: Found Fast University stop within 2km, prioritizing it');
            nearest = stop;
            minDistance = distance;
            break; // Use Fast University stop if it's within 2km
          }
        }
        
        if (distance < minDistance) {
          minDistance = distance;
          nearest = stop;
        }
      } catch (e) {
        // Skip invalid stop data
        continue;
      }
    }
    
    if (nearest != null) {
      print('🎯 RouteFinder: Selected nearest stop: ${nearest.name} (${DistanceCalculator.formatDistance(minDistance)})');
      
      // Debug: Show why this stop was chosen for Fast University area
      if (isFastUniversityArea) {
        
        
        // Check if Fast University stop exists and show its distance
        final fastUniversityStop = stops.where((s) => 
          s.name.toLowerCase().contains('fast') || 
          s.name.toLowerCase().contains('university')
        ).firstOrNull;
        
        if (fastUniversityStop != null) {
          final fastUniversityDistance = DistanceCalculator.calculateDistance(
            lat, lng, fastUniversityStop.lat, fastUniversityStop.lng
          );
          print('   - Fast University stop distance: ${DistanceCalculator.formatDistance(fastUniversityDistance)}');
          print('   - Difference: ${DistanceCalculator.formatDistance(fastUniversityDistance - minDistance)}');
        }
      }
    }
    
    return nearest;
  }
  
  List<Stop> _findMultipleNearestStops(double lat, double lng, List<Stop> stops, int count) {
    if (stops.isEmpty) return [];
    
    final sortedStops = stops.toList();
    sortedStops.sort((a, b) {
      try {
        final distanceA = DistanceCalculator.calculateDistance(lat, lng, a.lat, a.lng);
        final distanceB = DistanceCalculator.calculateDistance(lat, lng, b.lat, b.lng);
        return distanceA.compareTo(distanceB);
      } catch (e) {
        return 0;
      }
    });
    
    return sortedStops.take(count).toList();
  }
  
  Stop? _findBestBoardingStop(
    double userLat,
    double userLng,
    Stop destinationStop,
    List<Stop> allStops,
  ) {
    // Find stops that share routes with destination stop
    print('🎯 RouteFinder: Finding stops that can reach destination: ${destinationStop.name}');
    print('🎯 RouteFinder: Destination routes: ${destinationStop.routes.join(', ')}');
    
    final viableStops = allStops.where((stop) {
      final hasCommonRoute = stop.routes.any((route) => destinationStop.routes.contains(route));
      if (hasCommonRoute) {
        print('   ✅ ${stop.name}: Can reach destination via routes: ${stop.routes.where((route) => destinationStop.routes.contains(route)).join(', ')}');
      }
      return hasCommonRoute;
    }).toList();
    
    print('🎯 RouteFinder: Found ${viableStops.length} stops that can reach destination');
    
    if (viableStops.isEmpty) {
      // If no direct route, find transfer options
      return _findTransferRoute(userLat, userLng, destinationStop, allStops);
    }
    
    // Prioritize routes that actually go to the destination
    // Instead of just finding the nearest stop, find the best route-based option
    return _findBestRouteBasedBoardingStop(
      userLat, userLng, destinationStop, viableStops
    );
  }
  
  Stop? _findBestRouteBasedBoardingStop(
    double userLat,
    double userLng,
    Stop destinationStop,
    List<Stop> viableStops,
  ) {
    // Group stops by their routes to the destination
    final Map<String, List<Stop>> routeGroups = {};
    
    for (final stop in viableStops) {
      final commonRoutes = stop.routes
          .where((route) => destinationStop.routes.contains(route))
          .toList();
      
      for (final route in commonRoutes) {
        routeGroups.putIfAbsent(route, () => []).add(stop);
      }
    }
    
    print('🛣️ RouteFinder: Analyzing ${routeGroups.length} routes to destination');
    
    // PRIORITY 1: Find routes that go directly to destination or very close to it
    final directRouteOptions = _findDirectRouteOptions(
      userLat, userLng, destinationStop, routeGroups
    );
    
    if (directRouteOptions.isNotEmpty) {
      print('🎯 RouteFinder: Found ${directRouteOptions.length} direct route options');
      final bestDirectOption = directRouteOptions.first;
      print('🚌 RouteFinder: Selected direct route: ${bestDirectOption['route']} '
            'from ${bestDirectOption['stop'].name} '
            '(User distance: ${DistanceCalculator.formatDistance(bestDirectOption['distanceToUser'])}, '
            'Destination proximity: ${DistanceCalculator.formatDistance(bestDirectOption['distanceToDestination'])})');
      
      // Show why this stop was chosen
      print('✅ RouteFinder: Chose ${bestDirectOption['stop'].name} because it\'s the ${bestDirectOption['priority']} option with best user proximity');
      
      return bestDirectOption['stop'] as Stop;
    }
    
    // PRIORITY 2: Find the closest stop from user's location that leads to closest stop to destination
    print('📍 RouteFinder: No direct routes found, using proximity-based approach');
    final proximityRouteOptions = _findProximityBasedRouteOptions(
      userLat, userLng, destinationStop, routeGroups
    );
    
    if (proximityRouteOptions.isNotEmpty) {
      final bestProximityOption = proximityRouteOptions.first;
     
      
      // Show why this stop was chosen
      print('✅ RouteFinder: Chose ${bestProximityOption['stop'].name} because it\'s the closest stop to user (${bestProximityOption['priority']} priority)');
      
      return bestProximityOption['stop'] as Stop;
    }
    
    // Fallback: Check if destination is very close to a BRT stop (within 500m)
    final distanceToDestinationStop = DistanceCalculator.calculateDistance(
      userLat, userLng, destinationStop.lat, destinationStop.lng
    );
    
    if (distanceToDestinationStop < 500) {
      print('🚶 RouteFinder: Destination is very close to BRT stop (${DistanceCalculator.formatDistance(distanceToDestinationStop)}). Suggesting walking instead of bus.');
      return null;
    }
    
    return null;
  }
  
  /// PRIORITY 1: Find routes that go directly to destination or very close to it
  List<Map<String, dynamic>> _findDirectRouteOptions(
    double userLat,
    double userLng,
    Stop destinationStop,
    Map<String, List<Stop>> routeGroups,
  ) {
    final List<Map<String, dynamic>> directOptions = [];
    const double veryCloseThreshold = 1000; // 1km - very close to destination
    const double closeThreshold = 2000; // 2km - close to destination
    
    for (final entry in routeGroups.entries) {
      final routeName = entry.key;
      final stopsOnRoute = entry.value;
      
      print('   📍 Route $routeName: Finding closest stop to user that goes to destination');
      
      // Find the stop CLOSEST TO USER on this route that goes to destination
      Stop? closestStopToUser;
      double minDistanceToUser = double.infinity;
      
      for (final stop in stopsOnRoute) {
        // Skip if this is the same as the destination stop
        if (stop.id == destinationStop.id) {
          print('      ⏭️ Skipping ${stop.name} - same as destination stop');
          continue;
        }
        
        // Calculate distance from this stop to destination
        final distanceToDestination = DistanceCalculator.calculateDistance(
          stop.lat, stop.lng, destinationStop.lat, destinationStop.lng
        );
        
        // Calculate distance from user to this stop
        final distanceToUser = DistanceCalculator.calculateDistance(
          userLat, userLng, stop.lat, stop.lng
        );
        
        // Check if this route goes directly to the destination stop (0 distance)
        if (distanceToDestination == 0) {
          // This stop goes directly to destination - check if it's closest to user
          if (distanceToUser < minDistanceToUser) {
            minDistanceToUser = distanceToUser;
            closestStopToUser = stop;
          }
          print('      🎯 ${stop.name}: EXACT DESTINATION STOP (${DistanceCalculator.formatDistance(distanceToDestination)}) - User distance: ${DistanceCalculator.formatDistance(distanceToUser)}');
        }
        // Check if this route goes very close to destination
        else if (distanceToDestination <= veryCloseThreshold) {
          // This stop goes very close to destination - check if it's closest to user
          if (distanceToUser < minDistanceToUser) {
            minDistanceToUser = distanceToUser;
            closestStopToUser = stop;
          }
          print('      🎯 ${stop.name}: VERY CLOSE to destination (${DistanceCalculator.formatDistance(distanceToDestination)}) - User distance: ${DistanceCalculator.formatDistance(distanceToUser)}');
        }
        // Check if this route goes close to destination
        else if (distanceToDestination <= closeThreshold) {
          // This stop goes close to destination - check if it's closest to user
          if (distanceToUser < minDistanceToUser) {
            minDistanceToUser = distanceToUser;
            closestStopToUser = stop;
          }
          print('      🎯 ${stop.name}: CLOSE to destination (${DistanceCalculator.formatDistance(distanceToDestination)}) - User distance: ${DistanceCalculator.formatDistance(distanceToUser)}');
        }
        // Debug: Print info for Fast University specifically
        else if (destinationStop.name.toLowerCase().contains('fast') || destinationStop.name.toLowerCase().contains('university')) {
          print('      🔍 ${stop.name} -> ${destinationStop.name}: ${DistanceCalculator.formatDistance(distanceToDestination)} - User distance: ${DistanceCalculator.formatDistance(distanceToUser)}');
        }
      }
      
      // Add the CLOSEST stop to user on this route (if any found)
      if (closestStopToUser != null) {
        final distanceToDestination = DistanceCalculator.calculateDistance(
          closestStopToUser.lat, closestStopToUser.lng, destinationStop.lat, destinationStop.lng
        );
        
        String priority;
        if (distanceToDestination == 0) {
          priority = 'exact_destination';
        } else if (distanceToDestination <= veryCloseThreshold) {
          priority = 'very_close';
        } else {
          priority = 'close';
        }
        
        directOptions.add({
          'route': routeName,
          'stop': closestStopToUser,
          'score': minDistanceToUser, // Score is distance to user (lower is better)
          'distanceToUser': minDistanceToUser,
          'distanceToDestination': distanceToDestination,
          'priority': priority,
        });
        
        print('      ✅ Route $routeName: Closest stop to user is ${closestStopToUser.name} (${DistanceCalculator.formatDistance(minDistanceToUser)} from user)');
      }
    }
    
    // Sort by priority first, then by distance to user (closest first)
    directOptions.sort((a, b) {
      // First sort by priority (exact_destination > very_close > close)
      final priorityA = a['priority'] as String;
      final priorityB = b['priority'] as String;
      if (priorityA != priorityB) {
        if (priorityA == 'exact_destination') return -1;
        if (priorityB == 'exact_destination') return 1;
        if (priorityA == 'very_close') return -1;
        if (priorityB == 'very_close') return 1;
      }
      // Then sort by distance to user (closest first)
      return a['distanceToUser'].compareTo(b['distanceToUser']);
    });
    
    return directOptions;
  }
  
  /// PRIORITY 2: Find the closest stop from user's location that leads to closest stop to destination
  List<Map<String, dynamic>> _findProximityBasedRouteOptions(
    double userLat,
    double userLng,
    Stop destinationStop,
    Map<String, List<Stop>> routeGroups,
  ) {
    final List<Map<String, dynamic>> proximityOptions = [];
    
    for (final entry in routeGroups.entries) {
      final routeName = entry.key;
      final stopsOnRoute = entry.value;
      
      print('   📍 Route $routeName: Finding closest stop to user');
      
      // Find the stop CLOSEST TO USER on this route
      Stop? closestStopToUser;
      double minDistanceToUser = double.infinity;
      
      for (final stop in stopsOnRoute) {
        // Skip if this is the same as the destination stop
        if (stop.id == destinationStop.id) {
          print('      ⏭️ Skipping ${stop.name} - same as destination stop');
          continue;
        }
        
        // Calculate distance from user to this stop
        final distanceToUser = DistanceCalculator.calculateDistance(
          userLat, userLng, stop.lat, stop.lng
        );
        
        // Calculate distance from this stop to destination
        final distanceToDestination = DistanceCalculator.calculateDistance(
          stop.lat, stop.lng, destinationStop.lat, destinationStop.lng
        );
        
        // Find the stop closest to user on this route
        if (distanceToUser < minDistanceToUser) {
          minDistanceToUser = distanceToUser;
          closestStopToUser = stop;
        }
        
        print('      🚏 ${stop.name}: User distance ${DistanceCalculator.formatDistance(distanceToUser)}, '
              'Destination distance ${DistanceCalculator.formatDistance(distanceToDestination)}');
        
        // Debug: Show coordinates for verification
        if (stop.name.toLowerCase().contains('quaidabad') || 
            stop.name.toLowerCase().contains('abdullah') || 
            stop.name.toLowerCase().contains('razzakabad')) {
          print('         📍 ${stop.name} coordinates: (${stop.lat.toStringAsFixed(6)}, ${stop.lng.toStringAsFixed(6)})');
        }
      }
      
      if (closestStopToUser != null) {
        final distanceToDestination = DistanceCalculator.calculateDistance(
          closestStopToUser.lat, closestStopToUser.lng, destinationStop.lat, destinationStop.lng
        );
        
        proximityOptions.add({
          'route': routeName,
          'stop': closestStopToUser,
          'score': minDistanceToUser, // Score is distance to user (lower is better)
          'distanceToUser': minDistanceToUser,
          'distanceToDestination': distanceToDestination,
          'priority': 'proximity',
        });
        
        print('      ✅ Route $routeName: Closest stop to user is ${closestStopToUser.name} (${DistanceCalculator.formatDistance(minDistanceToUser)} from user)');
      }
    }
    
    // Sort by distance to user (closest first)
    proximityOptions.sort((a, b) => a['distanceToUser'].compareTo(b['distanceToUser']));
    
    return proximityOptions;
  }
  
  Stop? _findTransferRoute(
    double userLat,
    double userLng,
    Stop destinationStop,
    List<Stop> allStops,
  ) {
    // Simple transfer logic: find stops that can connect to destination via transfer
    final transferStops = <Stop>[];
    
    for (final stop in allStops) {
      // Check if this stop can reach destination via another stop
      final possibleTransfers = allStops.where((transferStop) {
        final hasCommonWithStop = stop.routes.any((route) => transferStop.routes.contains(route));
        final hasCommonWithDest = transferStop.routes.any((route) => destinationStop.routes.contains(route));
        return hasCommonWithStop && hasCommonWithDest && transferStop.id != stop.id;
      });
      
      if (possibleTransfers.isNotEmpty) {
        transferStops.add(stop);
      }
    }
    
    return _findNearestStop(userLat, userLng, transferStops);
  }
  
  Future<Journey?> _createEnhancedJourney({
    required double userLat,
    required double userLng,
    required double destLat,
    required double destLng,
    required Stop boardingStop,
    required Stop destinationStop,
  }) async {
    try {
      // Get Mapbox journey details for enhanced information
      final journeyDetails = await MapboxService.getJourneyDetails(
        startLat: userLat,
        startLng: userLng,
        endLat: destLat,
        endLng: destLng,
        busStopLat: boardingStop.lat,
        busStopLng: boardingStop.lng,
        destinationStopLat: destinationStop.lat,
        destinationStopLng: destinationStop.lng,
      );
      
      // Get walking directions to boarding stop
      final walkingToStop = await MapboxService.getWalkingDirectionsToStop(
        userLat: userLat,
        userLng: userLng,
        stopLat: boardingStop.lat,
        stopLng: boardingStop.lng,
      );
      
      // Get walking directions from destination stop to final destination
      final walkingFromStop = await MapboxService.getWalkingDirectionsToStop(
        userLat: destinationStop.lat,
        userLng: destinationStop.lng,
        stopLat: destLat,
        stopLng: destLng,
      );
      
      // Use Mapbox data if available, otherwise fall back to basic calculations
      final walkingDistanceToStart = (walkingToStop?['distance'] as num?)?.toDouble() ?? 
          DistanceCalculator.calculateDistance(userLat, userLng, boardingStop.lat, boardingStop.lng);
      
      final walkingDistanceFromEnd = (walkingFromStop?['distance'] as num?)?.toDouble() ?? 
          DistanceCalculator.calculateDistance(destinationStop.lat, destinationStop.lng, destLat, destLng);
      
      // Calculate bus distance using road network if possible
      double busDistance;
      if (boardingStop.id != destinationStop.id) {
        // Try to get road-based distance for bus journey
        final busRouteDirections = await MapboxService.getRouteDirections(
          startLat: boardingStop.lat,
          startLng: boardingStop.lng,
          endLat: destinationStop.lat,
          endLng: destinationStop.lng,
          profile: 'driving', // Use driving profile for bus routes
        );
        
        busDistance = (busRouteDirections?['distance'] as num?)?.toDouble() ?? 
            DistanceCalculator.calculateDistance(
              boardingStop.lat,
              boardingStop.lng,
              destinationStop.lat,
              destinationStop.lng,
            );
      } else {
        busDistance = 0.0; // Same stop, no bus journey
      }
      
      print('📏 RouteFinder: Distance breakdown:');
      print('   - Walking to boarding stop: ${DistanceCalculator.formatDistance(walkingDistanceToStart)}');
      print('   - Bus journey: ${DistanceCalculator.formatDistance(busDistance)}');
      print('   - Walking from destination stop: ${DistanceCalculator.formatDistance(walkingDistanceFromEnd)}');
      print('   - Total: ${DistanceCalculator.formatDistance(walkingDistanceToStart + busDistance + walkingDistanceFromEnd)}');
      
      // Debug: Check if boarding and destination stops are the same
      if (boardingStop.id == destinationStop.id) {
        print('⚠️ RouteFinder: WARNING - Boarding and destination stops are the same!');
        print('   Boarding stop: ${boardingStop.name} (${boardingStop.id})');
        print('   Destination stop: ${destinationStop.name} (${destinationStop.id})');
        print('   Bus distance: ${DistanceCalculator.formatDistance(busDistance)}');
      }
      
      // Check if destination is at the exact bus stop
      if (walkingDistanceFromEnd < 50) {
        print('🎯 RouteFinder: Destination is at the exact bus stop: ${destinationStop.name}');
        print('   No additional walking needed from bus stop to destination');
      }
      
      // Find common routes
      final commonRoutes = boardingStop.routes
          .where((route) => destinationStop.routes.contains(route))
          .toList();
      
      final busRoutes = commonRoutes.map((routeName) {
        final route = _dataService.getRouteByName(routeName);
        return route ?? BusRoute(name: routeName, stops: [boardingStop, destinationStop]);
      }).toList();
      
      // Check if transfer is needed
      Stop? transferStop;
      if (commonRoutes.isEmpty) {
        // Find transfer stop
        transferStop = _findTransferStopBetween(boardingStop, destinationStop);
      }
      
      final instructions = _generateEnhancedInstructions(
        boardingStop: boardingStop,
        destinationStop: destinationStop,
        transferStop: transferStop,
        walkingDistanceToStart: walkingDistanceToStart,
        walkingDistanceFromEnd: walkingDistanceFromEnd,
        routes: commonRoutes,
        journeyDetails: journeyDetails,
        walkingToStop: walkingToStop,
        walkingFromStop: walkingFromStop,
      );
      
      return Journey(
        startStop: boardingStop,
        endStop: destinationStop,
        routes: busRoutes,
        transferStop: transferStop,
        totalDistance: walkingDistanceToStart + busDistance + walkingDistanceFromEnd,
        instructions: instructions,
        walkingDistanceToStart: walkingDistanceToStart,
        walkingDistanceFromEnd: walkingDistanceFromEnd,
        busDistance: busDistance,
      );
    } catch (e) {
      print('Error creating enhanced journey: $e');
      // Fall back to basic journey creation
      return _createBasicJourney(
        userLat: userLat,
        userLng: userLng,
        destLat: destLat,
        destLng: destLng,
        boardingStop: boardingStop,
        destinationStop: destinationStop,
      );
    }
  }
  
  Journey _createBasicJourney({
    required double userLat,
    required double userLng,
    required double destLat,
    required double destLng,
    required Stop boardingStop,
    required Stop destinationStop,
  }) {
    final walkingDistanceToStart = DistanceCalculator.calculateDistance(
      userLat,
      userLng,
      boardingStop.lat,
      boardingStop.lng,
    );
    
    final walkingDistanceFromEnd = DistanceCalculator.calculateDistance(
      destinationStop.lat,
      destinationStop.lng,
      destLat,
      destLng,
    );
    
    // Calculate bus distance with improved accuracy
    final double busDistance = boardingStop.id != destinationStop.id ? 
        DistanceCalculator.calculateDistance(
          boardingStop.lat,
          boardingStop.lng,
          destinationStop.lat,
          destinationStop.lng,
        ) : 0.0;
    
    print('📏 RouteFinder: Basic journey distance breakdown:');
    print('   - Walking to boarding stop: ${DistanceCalculator.formatDistance(walkingDistanceToStart)}');
    print('   - Bus journey: ${DistanceCalculator.formatDistance(busDistance)}');
    print('   - Walking from destination stop: ${DistanceCalculator.formatDistance(walkingDistanceFromEnd)}');
    print('   - Total: ${DistanceCalculator.formatDistance(walkingDistanceToStart + busDistance + walkingDistanceFromEnd)}');
    
    // Debug: Check if boarding and destination stops are the same
    if (boardingStop.id == destinationStop.id) {
      print('⚠️ RouteFinder: WARNING - Boarding and destination stops are the same! (Basic journey)');
      print('   Boarding stop: ${boardingStop.name} (${boardingStop.id})');
      print('   Destination stop: ${destinationStop.name} (${destinationStop.id})');
      print('   Bus distance: ${DistanceCalculator.formatDistance(busDistance)}');
    }
    
    // Find common routes
    final commonRoutes = boardingStop.routes
        .where((route) => destinationStop.routes.contains(route))
        .toList();
    
    final busRoutes = commonRoutes.map((routeName) {
      final route = _dataService.getRouteByName(routeName);
      return route ?? BusRoute(name: routeName, stops: [boardingStop, destinationStop]);
    }).toList();
    
    // Check if transfer is needed
    Stop? transferStop;
    if (commonRoutes.isEmpty) {
      // Find transfer stop
      transferStop = _findTransferStopBetween(boardingStop, destinationStop);
    }
    
    final instructions = _generateInstructions(
      boardingStop: boardingStop,
      destinationStop: destinationStop,
      transferStop: transferStop,
      walkingDistanceToStart: walkingDistanceToStart,
      walkingDistanceFromEnd: walkingDistanceFromEnd,
      routes: commonRoutes,
    );
    
          return Journey(
        startStop: boardingStop,
        endStop: destinationStop,
        routes: busRoutes,
        transferStop: transferStop,
        totalDistance: walkingDistanceToStart + busDistance + walkingDistanceFromEnd,
        instructions: instructions,
        walkingDistanceToStart: walkingDistanceToStart,
        walkingDistanceFromEnd: walkingDistanceFromEnd,
        busDistance: busDistance,
      );
  }
  
  Stop? _findTransferStopBetween(Stop start, Stop end) {
    final allStops = _dataService.stops;
    
    for (final stop in allStops) {
      final hasCommonWithStart = stop.routes.any((route) => start.routes.contains(route));
      final hasCommonWithEnd = stop.routes.any((route) => end.routes.contains(route));
      
      if (hasCommonWithStart && hasCommonWithEnd && stop.id != start.id && stop.id != end.id) {
        return stop;
      }
    }
    
    return null;
  }
  
  String _generateEnhancedInstructions({
    required Stop boardingStop,
    required Stop destinationStop,
    required double walkingDistanceToStart,
    required double walkingDistanceFromEnd,
    required List<String> routes,
    Stop? transferStop,
    Map<String, dynamic>? journeyDetails,
    Map<String, dynamic>? walkingToStop,
    Map<String, dynamic>? walkingFromStop,
  }) {
    final buffer = StringBuffer();
    
    // Step 1: Get to boarding stop with enhanced details
    final double walkingTimeToStop = (walkingToStop?['duration'] as num?)?.toDouble() ?? 
        DistanceCalculator.calculateWalkingTimeMinutes(walkingDistanceToStart).toDouble();
    
    if (walkingDistanceToStart < 500) {
      buffer.writeln('1. Walk ${DistanceCalculator.formatDistance(walkingDistanceToStart)} to ${boardingStop.name} stop (${(walkingTimeToStop / 60).round()} min)');
    } else if (walkingDistanceToStart < 2000) {
      buffer.writeln('1. Take a rickshaw (${DistanceCalculator.formatDistance(walkingDistanceToStart)}) to ${boardingStop.name} stop');
    } else {
      buffer.writeln('1. Take Bykea/Careem (${DistanceCalculator.formatDistance(walkingDistanceToStart)}) to ${boardingStop.name} stop');
    }
    
    // Add traffic information if available
    if (journeyDetails != null && journeyDetails['trafficInfo'] != null) {
      final trafficLevel = journeyDetails['trafficInfo']['trafficLevel'];
      buffer.writeln('   Traffic: $trafficLevel');
    }
    
    // Step 2: Bus journey
    if (transferStop != null) {
      buffer.writeln('2. Take ${routes.isNotEmpty ? routes.first : "available route"} bus to ${transferStop.name}');
      buffer.writeln('3. Transfer to another bus heading to ${destinationStop.name}');
    } else {
      final routeText = routes.isNotEmpty ? routes.join(' or ') : 'available route';
      buffer.writeln('2. Take $routeText bus to ${destinationStop.name}');
    }
    
    // Step 3: Get to final destination with enhanced details
    final finalStepNumber = transferStop != null ? 4 : 3;
    final double walkingTimeFromStop = (walkingFromStop?['duration'] as num?)?.toDouble() ?? 
        DistanceCalculator.calculateWalkingTimeMinutes(walkingDistanceFromEnd).toDouble();
    
    // Check if destination is at the bus stop (no additional walking needed)
    if (walkingDistanceFromEnd < 50) {
      buffer.writeln('$finalStepNumber. Arrive at ${destinationStop.name} - your destination is at this bus stop!');
    } else if (walkingDistanceFromEnd < 500) {
      buffer.writeln('$finalStepNumber. Walk ${DistanceCalculator.formatDistance(walkingDistanceFromEnd)} to your destination (${(walkingTimeFromStop / 60).round()} min)');
    } else if (walkingDistanceFromEnd < 2000) {
      buffer.writeln('$finalStepNumber. Take a rickshaw (${DistanceCalculator.formatDistance(walkingDistanceFromEnd)}) to your destination');
    } else {
      buffer.writeln('$finalStepNumber. Take Bykea/Careem (${DistanceCalculator.formatDistance(walkingDistanceFromEnd)}) to your destination');
    }
    
    // Add total journey time if available
    if (journeyDetails != null && journeyDetails['totalWalkingDuration'] != null) {
      final totalTime = (journeyDetails['totalWalkingDuration'] / 60).round();
      buffer.writeln('\nTotal estimated time: $totalTime minutes');
    }
    
    return buffer.toString();
  }
  
  String _generateInstructions({
    required Stop boardingStop,
    required Stop destinationStop,
    required double walkingDistanceToStart,
    required double walkingDistanceFromEnd,
    required List<String> routes,
    Stop? transferStop,
  }) {
    final buffer = StringBuffer();
    
    // Step 1: Get to boarding stop
    if (walkingDistanceToStart < 500) {
      buffer.writeln('1. Walk ${DistanceCalculator.formatDistance(walkingDistanceToStart)} to ${boardingStop.name} stop');
    } else if (walkingDistanceToStart < 2000) {
      buffer.writeln('1. Take a rickshaw (${DistanceCalculator.formatDistance(walkingDistanceToStart)}) to ${boardingStop.name} stop');
    } else {
      buffer.writeln('1. Take Bykea/Careem (${DistanceCalculator.formatDistance(walkingDistanceToStart)}) to ${boardingStop.name} stop');
    }
    
    // Step 2: Bus journey
    if (transferStop != null) {
      buffer.writeln('2. Take ${routes.isNotEmpty ? routes.first : "available route"} bus to ${transferStop.name}');
      buffer.writeln('3. Transfer to another bus heading to ${destinationStop.name}');
    } else {
      final routeText = routes.isNotEmpty ? routes.join(' or ') : 'available route';
      buffer.writeln('2. Take $routeText bus to ${destinationStop.name}');
    }
    
    // Step 3: Get to final destination
    final finalStepNumber = transferStop != null ? 4 : 3;
    // Check if destination is at the bus stop (no additional walking needed)
    if (walkingDistanceFromEnd < 50) {
      buffer.writeln('$finalStepNumber. Arrive at ${destinationStop.name} - your destination is at this bus stop!');
    } else if (walkingDistanceFromEnd < 500) {
      buffer.writeln('$finalStepNumber. Walk ${DistanceCalculator.formatDistance(walkingDistanceFromEnd)} to your destination');
    } else if (walkingDistanceFromEnd < 2000) {
      buffer.writeln('$finalStepNumber. Take a rickshaw (${DistanceCalculator.formatDistance(walkingDistanceFromEnd)}) to your destination');
    } else {
      buffer.writeln('$finalStepNumber. Take Bykea/Careem (${DistanceCalculator.formatDistance(walkingDistanceFromEnd)}) to your destination');
    }
    
    return buffer.toString();
  }
  
  int _calculateTotalJourneyTime(Journey journey) {
    return DistanceCalculator.calculateJourneyTimeWithBykea(
      distanceToBusStop: journey.walkingDistanceToStart,
      busJourneyDistance: journey.busDistance,
      distanceFromBusStopToDestination: journey.walkingDistanceFromEnd,
      requiresTransfer: journey.requiresTransfer,
      departureTime: DateTime.now(),
    );
  }
  
  Future<Journey?> _createWalkingOnlyJourney({
    required double userLat,
    required double userLng,
    required double destLat,
    required double destLng,
    required Stop destinationStop,
  }) async {
    try {
      // Calculate total walking distance with road network adjustment
      final totalWalkingDistance = DistanceCalculator.calculateDistance(
        userLat, userLng, destLat, destLng
      );
      
      // Get walking directions
      final walkingDirections = await MapboxService.getWalkingDirectionsToStop(
        userLat: userLat,
        userLng: userLng,
        stopLat: destLat,
        stopLng: destLng,
      );
      
      final double walkingTime = (walkingDirections?['duration'] as num?)?.toDouble() ?? 
          DistanceCalculator.calculateWalkingTimeMinutes(totalWalkingDistance).toDouble();
      
      final instructions = _generateWalkingOnlyInstructions(
        totalDistance: totalWalkingDistance,
        walkingTime: walkingTime,
        destinationName: destinationStop.name,
      );
      
      print('🚶 RouteFinder: Created walking-only journey (${DistanceCalculator.formatDistance(totalWalkingDistance)})');
      
      return Journey(
        startStop: destinationStop, // Use destination stop as both start and end
        endStop: destinationStop,
        routes: [], // No bus routes for walking-only journey
        transferStop: null,
        totalDistance: totalWalkingDistance,
        instructions: instructions,
        walkingDistanceToStart: totalWalkingDistance, // All distance is walking
        walkingDistanceFromEnd: 0, // No additional walking from bus stop
        busDistance: 0, // No bus journey for walking-only
      );
    } catch (e) {
      print('Error creating walking-only journey: $e');
      return null;
    }
  }
  
  String _generateWalkingOnlyInstructions({
    required double totalDistance,
    required double walkingTime,
    required String destinationName,
  }) {
    final buffer = StringBuffer();
    
    if (totalDistance < 500) {
      buffer.writeln('1. Walk ${DistanceCalculator.formatDistance(totalDistance)} to $destinationName (${(walkingTime / 60).round()} min)');
    } else if (totalDistance < 2000) {
      buffer.writeln('1. Take a rickshaw (${DistanceCalculator.formatDistance(totalDistance)}) to $destinationName');
    } else {
      buffer.writeln('1. Take Bykea/Careem (${DistanceCalculator.formatDistance(totalDistance)}) to $destinationName');
    }
    
    buffer.writeln('\nTotal estimated time: ${(walkingTime / 60).round()} minutes');
    buffer.writeln('Note: No bus journey needed - destination is within walking/riding distance');
    
    return buffer.toString();
  }
}
