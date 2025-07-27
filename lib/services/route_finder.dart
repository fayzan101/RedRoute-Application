import 'package:flutter/foundation.dart';
import '../models/stop.dart';
import '../models/route.dart';
import '../utils/distance_calculator.dart';
import 'data_service.dart';
import 'mapbox_service.dart';
import 'mapbox_directions_service.dart';
import 'secure_token_service.dart';

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
    // Clear any existing rate limit data to ensure fresh API calls
    await clearRateLimit();
    
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
    final destinationStop = await _findExactBusStop(destLat, destLng, stops);
    if (destinationStop != null) {
      print('🎯 RouteFinder: Destination is at bus stop: ${destinationStop.name} (${destinationStop.routes.join(', ')})');
      
      // Find best boarding stop for user to reach this exact destination stop
      final bestBoardingStop = await _findBestBoardingStop(
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
      nearestToDestination = await _findNearestStop(destLat, destLng, stops);
    }
    
    if (nearestToDestination == null) return null;
    
    print('🎯 RouteFinder: Nearest stop to destination: ${nearestToDestination.name} (${nearestToDestination.routes.join(', ')})');
    
    // Find best boarding stop for user
    final bestBoardingStop = await _findBestBoardingStop(
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
    // Clear any existing rate limit data to ensure fresh API calls
    await clearRateLimit();
    
    await _dataService.loadBRTData();
    
    final stops = _dataService.stops;
    if (stops.isEmpty) return [];
    
    // Check if destination is at a bus stop (within 50 meters)
    final destinationStop = await _findExactBusStop(destLat, destLng, stops);
    if (destinationStop != null) {
      print('🎯 RouteFinder: Destination is at bus stop: ${destinationStop.name} (${destinationStop.routes.join(', ')})');
      
      // Find all viable boarding stops that can reach this exact destination stop
      final viableStops = stops.where((stop) {
        return stop.routes.any((route) => destinationStop.routes.contains(route));
      }).toList();
      
      if (viableStops.isEmpty) {
        // If no direct route, find transfer options
        final transferStop = await _findTransferRoute(userLat, userLng, destinationStop, stops);
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
      final routeOptions = await _getMultipleRouteOptions(
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
    final nearestToDestination = await _findNearestStop(destLat, destLng, stops);
    if (nearestToDestination == null) return [];
    
    // Find all viable boarding stops with route-based prioritization
    final viableStops = stops.where((stop) {
      return stop.routes.any((route) => nearestToDestination.routes.contains(route));
    }).toList();
    
    if (viableStops.isEmpty) {
      // If no direct route, find transfer options
      final transferStop = await _findTransferRoute(userLat, userLng, nearestToDestination, stops);
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
    final routeOptions = await _getMultipleRouteOptions(
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
  
  /// Get multiple route options using Mapbox driving profile distance
  Future<List<Map<String, dynamic>>> _getMultipleRouteOptions(
    double userLat,
    double userLng,
    Stop destinationStop,
    List<Stop> viableStops,
    int maxOptions,
  ) async {
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
    final directRouteOptions = await _findDirectRouteOptions(
      userLat, userLng, destinationStop, routeGroups
    );
    allRouteOptions.addAll(directRouteOptions);
    
    // PRIORITY 2: Find the closest stop from user's location that leads to closest stop to destination
    final proximityRouteOptions = await _findProximityBasedRouteOptions(
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
  /// Find exact bus stop using optimized 2-level filtering strategy
  Future<Stop?> _findExactBusStop(double lat, double lng, List<Stop> stops) async {
    if (stops.isEmpty) return null;
    
    const double exactStopThreshold = 100; // 100 meters - destination is at this bus stop
    
    print('🚀 RouteFinder: Using OPTIMIZED 2-level filtering for exact bus stop...');
    print('📍 RouteFinder: User location: (${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})');
    
    // STEP 1: Filter using Haversine Distance (Locally) - NO API CALLS
    print('🔹 Step 1: Local Haversine filtering for exact stops...');
    final List<Map<String, dynamic>> candidateStops = [];
    
    for (final stop in stops) {
      try {
        final localDistance = DistanceCalculator.calculateDistance(
          lat,
          lng,
          stop.lat,
          stop.lng,
        );
        
        // Debug: Print distance to Fast University specifically
        if (stop.name.toLowerCase().contains('fast') || stop.name.toLowerCase().contains('university')) {
          print('🎓 RouteFinder: Local distance to ${stop.name}: ${DistanceCalculator.formatDistance(localDistance)}');
        }
        
        // Add to candidates if within reasonable distance (500m)
        if (localDistance <= 500) {
          candidateStops.add({
            'stop': stop,
            'localDistance': localDistance,
          });
        }
      } catch (e) {
        print('⚠️ RouteFinder: Error calculating local distance to ${stop.name}: $e');
        continue;
      }
    }
    
    // Sort by local distance
    candidateStops.sort((a, b) => a['localDistance'].compareTo(b['localDistance']));
    
    print('🔹 Step 1 Complete: Found ${candidateStops.length} candidate exact stops');
    for (int i = 0; i < candidateStops.length; i++) {
      final candidate = candidateStops[i];
      final stop = candidate['stop'] as Stop;
      final localDistance = candidate['localDistance'] as double;
      print('   ${i + 1}. ${stop.name}: ${DistanceCalculator.formatDistance(localDistance)}');
    }
    
    if (candidateStops.isEmpty) {
      print('❌ RouteFinder: No candidate exact stops found within 500m');
      return null;
    }
    
    // STEP 2: Use Mapbox Directions API for candidates only
    print('🔹 Step 2: Mapbox driving distance for ${candidateStops.length} exact stop candidates...');
    
    for (final candidate in candidateStops) {
      final stop = candidate['stop'] as Stop;
      final localDistance = candidate['localDistance'] as double;
      
      try {
        print('🗺️ RouteFinder: Getting Mapbox route for exact stop ${stop.name} (local: ${DistanceCalculator.formatDistance(localDistance)})...');
        final routeInfo = await MapboxDirectionsService.getRouteInfo(
          startLat: lat,
          startLng: lng,
          endLat: stop.lat,
          endLng: stop.lng,
          routeType: MapboxRouteType.driving,
        );
        
        double drivingDistance;
        if (routeInfo != null && routeInfo.distance > 0) {
          drivingDistance = routeInfo.distance;
          print('✅ RouteFinder: ${stop.name} - Mapbox driving distance: ${DistanceCalculator.formatDistance(drivingDistance)}');
        } else {
          // Fallback to local distance if Mapbox fails
          drivingDistance = localDistance * 1.4; // Apply road network factor
          print('⚠️ RouteFinder: ${stop.name} - Mapbox failed, using adjusted local distance: ${DistanceCalculator.formatDistance(drivingDistance)}');
        }
        
        if (drivingDistance <= exactStopThreshold) {
          print('🎯 RouteFinder: Destination is at bus stop ${stop.name} (driving distance: ${DistanceCalculator.formatDistance(drivingDistance)})');
          return stop;
        }
      } catch (e) {
        print('⚠️ RouteFinder: Mapbox error for ${stop.name}: $e, using fallback');
        // Use fallback calculation
        final drivingDistance = localDistance * 1.4;
        if (drivingDistance <= exactStopThreshold) {
          print('🎯 RouteFinder: Destination is at bus stop ${stop.name} (fallback distance: ${DistanceCalculator.formatDistance(drivingDistance)})');
          return stop;
        }
      }
    }
    
    print('❌ RouteFinder: No exact bus stop found within ${exactStopThreshold}m driving distance');
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

  /// Find nearest stop using optimized 2-level filtering strategy
  Future<Stop?> _findNearestStop(double lat, double lng, List<Stop> stops) async {
    if (stops.isEmpty) return null;
    
    print('🚀 RouteFinder: Using OPTIMIZED 2-level filtering strategy');
    print('📍 RouteFinder: User location: (${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})');
    print('📊 RouteFinder: Total stops to evaluate: ${stops.length}');
    
    // Debug: Check if this is for Fast University area
    final isFastUniversityArea = (lat >= 24.85 && lat <= 24.87 && lng >= 67.26 && lng <= 67.27);
    if (isFastUniversityArea) {
      print('🎓 RouteFinder: Searching for nearest stop in Fast University area');
    }
    
    // STEP 1: Filter using Haversine Distance (Locally) - NO API CALLS
    print('🔹 Step 1: Local Haversine filtering...');
    final List<Map<String, dynamic>> candidateStops = [];
    
    for (final stop in stops) {
      try {
        final localDistance = DistanceCalculator.calculateDistance(
          lat,
          lng,
          stop.lat,
          stop.lng,
        );
        
        // Debug: Show all stops within 10km for troubleshooting
        if (localDistance <= 10000) {
          print('🔍 RouteFinder: ${stop.name} - Local distance: ${DistanceCalculator.formatDistance(localDistance)} (${stop.lat.toStringAsFixed(6)}, ${stop.lng.toStringAsFixed(6)})');
        }
        
        // Special debugging for Manzil stops
        if (stop.name.toLowerCase().contains('manzil')) {
          print('🔍 RouteFinder: MANZIL STOP FOUND - ${stop.name}');
          print('   ID: ${stop.id}');
          print('   Coordinates: (${stop.lat.toStringAsFixed(6)}, ${stop.lng.toStringAsFixed(6)})');
          print('   Routes: ${stop.routes.join(', ')}');
          print('   Local distance: ${DistanceCalculator.formatDistance(localDistance)}');
        }
        
        // For Fast University area, prioritize stops that are actually closer
        if (isFastUniversityArea) {
          // If this is Fast University stop, give it priority if it's reasonably close
          if (stop.name.toLowerCase().contains('fast') && localDistance <= 2000) {
            print('🎓 RouteFinder: Found Fast University stop within 2km, prioritizing it');
            return stop; // Return immediately for Fast University
          }
        }
        
        // Add to candidates if within reasonable distance (10km)
        if (localDistance <= 10000) {
          candidateStops.add({
            'stop': stop,
            'localDistance': localDistance,
          });
        }
      } catch (e) {
        print('⚠️ RouteFinder: Error calculating local distance to ${stop.name}: $e');
        continue;
      }
    }
    
    // Sort by local distance and take top 1 candidate (single API call)
    candidateStops.sort((a, b) => a['localDistance'].compareTo(b['localDistance']));
    final topCandidates = candidateStops.take(1).toList();
    
    print('🔹 Step 1 Complete: Found ${topCandidates.length} candidate stops');
    for (int i = 0; i < topCandidates.length; i++) {
      final candidate = topCandidates[i];
      final stop = candidate['stop'] as Stop;
      final localDistance = candidate['localDistance'] as double;
      print('   ${i + 1}. ${stop.name}: ${DistanceCalculator.formatDistance(localDistance)}');
    }
    
    if (topCandidates.isEmpty) {
      print('❌ RouteFinder: No candidate stops found within 10km');
      return null;
    }
    
    // STEP 2: Use Mapbox Directions API for top 1 candidate only (single API call)
    print('🔹 Step 2: Mapbox driving distance for top ${topCandidates.length} candidate (MAX 1 API call)...');
    Stop? nearest;
    double minDistance = double.infinity;
    
    // Check if we should skip API calls due to rate limiting
    bool skipApiCalls = false;
    
    for (final candidate in topCandidates) {
      final stop = candidate['stop'] as Stop;
      final localDistance = candidate['localDistance'] as double;
      
      // Skip API calls if we're rate limited
      if (skipApiCalls) {
        print('⏭️ RouteFinder: Skipping API call for ${stop.name} due to rate limiting, using local distance');
        final drivingDistance = localDistance * 1.4;
        if (drivingDistance < minDistance) {
          minDistance = drivingDistance;
          nearest = stop;
          print('🔄 RouteFinder: New nearest stop (local fallback): ${stop.name} (${DistanceCalculator.formatDistance(drivingDistance)})');
        }
        continue;
      }
      
      try {
        print('🗺️ RouteFinder: Getting Mapbox route for ${stop.name} (local: ${DistanceCalculator.formatDistance(localDistance)})...');
        final routeInfo = await MapboxDirectionsService.getRouteInfo(
          startLat: lat,
          startLng: lng,
          endLat: stop.lat,
          endLng: stop.lng,
          routeType: MapboxRouteType.driving,
        );
        
        double drivingDistance;
        if (routeInfo != null && routeInfo.distance > 0) {
          drivingDistance = routeInfo.distance;
          print('✅ RouteFinder: ${stop.name} - Mapbox driving distance: ${DistanceCalculator.formatDistance(drivingDistance)}');
        } else {
          // Fallback to local distance if Mapbox fails
          drivingDistance = localDistance * 1.4; // Apply road network factor
          print('⚠️ RouteFinder: ${stop.name} - Mapbox failed, using adjusted local distance: ${DistanceCalculator.formatDistance(drivingDistance)}');
        }
        
        if (drivingDistance < minDistance) {
          minDistance = drivingDistance;
          nearest = stop;
          print('🔄 RouteFinder: New nearest stop found: ${stop.name} (${DistanceCalculator.formatDistance(drivingDistance)})');
        }
      } catch (e) {
        print('⚠️ RouteFinder: Mapbox error for ${stop.name}: $e, using fallback');
        // Check if this is a rate limiting error
        if (e.toString().contains('rate') || e.toString().contains('Rate')) {
          print('🚫 RouteFinder: Rate limiting detected, skipping remaining API calls');
          skipApiCalls = true;
        }
        // Use fallback calculation
        final drivingDistance = localDistance * 1.4;
        if (drivingDistance < minDistance) {
          minDistance = drivingDistance;
          nearest = stop;
          print('🔄 RouteFinder: New nearest stop (fallback): ${stop.name} (${DistanceCalculator.formatDistance(drivingDistance)})');
        }
      }
    }
    
    if (nearest != null) {
      print('🎯 RouteFinder: FINAL SELECTION - ${nearest.name} (${DistanceCalculator.formatDistance(minDistance)})');
      print('📍 RouteFinder: Selected stop coordinates: (${nearest.lat.toStringAsFixed(6)}, ${nearest.lng.toStringAsFixed(6)})');
      print('📍 RouteFinder: Selected stop routes: ${nearest.routes.join(', ')}');
      
      // Validate the selection
      final localDistanceToSelected = DistanceCalculator.calculateDistance(lat, lng, nearest.lat, nearest.lng);
      print('🔍 RouteFinder: Validation - Local distance to selected stop: ${DistanceCalculator.formatDistance(localDistanceToSelected)}');
      
      if (minDistance > 10000) {
        print('⚠️ RouteFinder: WARNING - Selected stop is very far (${DistanceCalculator.formatDistance(minDistance)})');
        print('⚠️ RouteFinder: This might indicate an issue with the selection algorithm');
      }
    } else {
      // Fallback: if no API calls succeeded, use the closest local distance
      print('🔄 RouteFinder: No API calls succeeded, using local distance fallback');
      if (topCandidates.isNotEmpty) {
        final fallbackCandidate = topCandidates.first;
        final fallbackStop = fallbackCandidate['stop'] as Stop;
        final fallbackDistance = fallbackCandidate['localDistance'] as double;
        nearest = fallbackStop;
        minDistance = fallbackDistance * 1.4; // Apply road network factor
        print('🎯 RouteFinder: FALLBACK SELECTION - ${fallbackStop.name} (${DistanceCalculator.formatDistance(minDistance)})');
      }
    }
    
    return nearest;
  }
  
  /// Clear rate limit data (for debugging)
  static Future<void> clearRateLimit() async {
    await SecureTokenService.clearRateLimit();
    print('🧹 RouteFinder: Rate limit data cleared');
  }

  /// Find multiple nearest stops using optimized 2-level filtering strategy
  Future<List<Stop>> _findMultipleNearestStops(double lat, double lng, List<Stop> stops, int count) async {
    if (stops.isEmpty) return [];
    
    print('🚀 RouteFinder: Using OPTIMIZED 2-level filtering to find $count nearest bus stops...');
    print('📍 RouteFinder: User location: (${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})');
    
    // STEP 1: Filter using Haversine Distance (Locally) - NO API CALLS
    print('🔹 Step 1: Local Haversine filtering...');
    final List<Map<String, dynamic>> candidateStops = [];
    
    for (final stop in stops) {
      try {
        final localDistance = DistanceCalculator.calculateDistance(lat, lng, stop.lat, stop.lng);
        
        // Add to candidates if within reasonable distance (10km)
        if (localDistance <= 10000) {
          candidateStops.add({
            'stop': stop,
            'localDistance': localDistance,
          });
        }
      } catch (e) {
        print('⚠️ RouteFinder: Error calculating local distance to ${stop.name}: $e');
        continue;
      }
    }
    
    // Sort by local distance and take top 1 candidate (single API call)
    candidateStops.sort((a, b) => a['localDistance'].compareTo(b['localDistance']));
    final topCandidates = candidateStops.take(1).toList();
    
    print('🔹 Step 1 Complete: Found ${topCandidates.length} candidate stops');
    
    if (topCandidates.isEmpty) {
      print('❌ RouteFinder: No candidate stops found within 10km');
      return [];
    }
    
    // STEP 2: Use Mapbox Directions API for top 1 candidate only (single API call)
    print('🔹 Step 2: Mapbox driving distance for top ${topCandidates.length} candidate (MAX 1 API call)...');
    final List<Map<String, dynamic>> stopDistances = [];
    
    for (final candidate in topCandidates) {
      final stop = candidate['stop'] as Stop;
      final localDistance = candidate['localDistance'] as double;
      
      try {
        print('🗺️ RouteFinder: Getting Mapbox route for ${stop.name} (local: ${DistanceCalculator.formatDistance(localDistance)})...');
        final routeInfo = await MapboxDirectionsService.getRouteInfo(
          startLat: lat,
          startLng: lng,
          endLat: stop.lat,
          endLng: stop.lng,
          routeType: MapboxRouteType.driving,
        );
        
        double drivingDistance;
        if (routeInfo != null && routeInfo.distance > 0) {
          drivingDistance = routeInfo.distance;
          print('✅ RouteFinder: ${stop.name} - Mapbox driving distance: ${DistanceCalculator.formatDistance(drivingDistance)}');
        } else {
          // Fallback to local distance if Mapbox fails
          drivingDistance = localDistance * 1.4; // Apply road network factor
          print('⚠️ RouteFinder: ${stop.name} - Mapbox failed, using adjusted local distance: ${DistanceCalculator.formatDistance(drivingDistance)}');
        }
        
        stopDistances.add({
          'stop': stop,
          'distance': drivingDistance,
        });
      } catch (e) {
        print('⚠️ RouteFinder: Mapbox error for ${stop.name}: $e, using fallback');
        // Use fallback calculation
        final drivingDistance = localDistance * 1.4;
        stopDistances.add({
          'stop': stop,
          'distance': drivingDistance,
        });
      }
    }
    
    // Sort by driving distance
    stopDistances.sort((a, b) => a['distance'].compareTo(b['distance']));
    
    // Return the top N stops
    final result = stopDistances.take(count).map((item) => item['stop'] as Stop).toList();
    print('🎯 RouteFinder: Returning ${result.length} nearest stops');
    return result;
  }
  
    /// Find best boarding stop using Mapbox driving profile distance
  Future<Stop?> _findBestBoardingStop(
    double userLat,
    double userLng,
    Stop destinationStop,
    List<Stop> allStops,
  ) async {
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
      return await _findTransferRoute(userLat, userLng, destinationStop, allStops);
    }
    
    // OPTIMIZATION: Use local distance filtering first, then only 1 API call
    print('🚀 RouteFinder: Using OPTIMIZED approach - local filtering + 1 API call');
    
    // Step 1: Calculate local distances for all viable stops
    final List<Map<String, dynamic>> stopDistances = [];
    for (final stop in viableStops) {
      final localDistance = DistanceCalculator.calculateDistance(userLat, userLng, stop.lat, stop.lng);
      stopDistances.add({
        'stop': stop,
        'localDistance': localDistance,
      });
    }
    
    // Step 2: Sort by local distance and take the closest one
    stopDistances.sort((a, b) => a['localDistance'].compareTo(b['localDistance']));
    final closestStop = stopDistances.first['stop'] as Stop;
    final localDistance = stopDistances.first['localDistance'] as double;
    
    print('🎯 RouteFinder: Closest stop by local distance: ${closestStop.name} (${DistanceCalculator.formatDistance(localDistance)})');
    
    // Step 3: Make only 1 API call to verify the closest stop
    try {
      print('🗺️ RouteFinder: Making 1 API call to verify ${closestStop.name}...');
      final routeInfo = await MapboxDirectionsService.getRouteInfo(
        startLat: userLat,
        startLng: userLng,
        endLat: closestStop.lat,
        endLng: closestStop.lng,
        routeType: MapboxRouteType.driving,
      );
      
      if (routeInfo != null && routeInfo.distance > 0) {
        print('✅ RouteFinder: ${closestStop.name} - Mapbox driving distance: ${DistanceCalculator.formatDistance(routeInfo.distance)}');
        return closestStop;
      } else {
        print('⚠️ RouteFinder: Mapbox failed for ${closestStop.name}, using local distance');
        return closestStop;
      }
    } catch (e) {
      print('⚠️ RouteFinder: Mapbox error for ${closestStop.name}: $e, using local distance');
      return closestStop;
    }
  }
  
  /// Find best route-based boarding stop using Mapbox driving profile distance
  Future<Stop?> _findBestRouteBasedBoardingStop(
    double userLat,
    double userLng,
    Stop destinationStop,
    List<Stop> viableStops,
  ) async {
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
    final directRouteOptions = await _findDirectRouteOptions(
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
    final proximityRouteOptions = await _findProximityBasedRouteOptions(
      userLat, userLng, destinationStop, routeGroups
    );
    
    if (proximityRouteOptions.isNotEmpty) {
      final bestProximityOption = proximityRouteOptions.first;
     
      
      // Show why this stop was chosen
      
      
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
  
  /// PRIORITY 1: Find routes that go directly to destination using local distance only (no API calls)
  Future<List<Map<String, dynamic>>> _findDirectRouteOptions(
    double userLat,
    double userLng,
    Stop destinationStop,
    Map<String, List<Stop>> routeGroups,
  ) async {
    final List<Map<String, dynamic>> directOptions = [];
    const double veryCloseThreshold = 1000; // 1km - very close to destination
    const double closeThreshold = 2000; // 2km - close to destination
    
    print('🚀 RouteFinder: Using LOCAL DISTANCE ONLY for direct route options (no API calls)');
    
    for (final entry in routeGroups.entries) {
      final routeName = entry.key;
      final stopsOnRoute = entry.value;
      
      print('   📍 Route $routeName: Finding closest stop to user using local distance');
      
      // Find the stop CLOSEST TO USER on this route that goes to destination
      Stop? closestStopToUser;
      double minDistanceToUser = double.infinity;
      
      for (final stop in stopsOnRoute) {
        // Skip if this is the same as the destination stop
        if (stop.id == destinationStop.id) {
          print('      ⏭️ Skipping ${stop.name} - same as destination stop');
          continue;
        }
        
        // Calculate distance from user to this stop using LOCAL distance only
        final distanceToUser = DistanceCalculator.calculateDistance(
          userLat, userLng, stop.lat, stop.lng
        ) * 1.4; // Apply road network factor
        
        // Calculate distance from this stop to destination using LOCAL distance only
        final distanceToDestination = DistanceCalculator.calculateDistance(
          stop.lat, stop.lng, destinationStop.lat, destinationStop.lng
        ) * 1.4; // Apply road network factor
        
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
        // Calculate distance to destination for the selected stop using LOCAL distance
        final distanceToDestination = DistanceCalculator.calculateDistance(
          closestStopToUser.lat, closestStopToUser.lng, destinationStop.lat, destinationStop.lng
        ) * 1.4; // Apply road network factor
        
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
  
  /// PRIORITY 2: Find the closest stop from user's location using local distance only (no API calls)
  Future<List<Map<String, dynamic>>> _findProximityBasedRouteOptions(
    double userLat,
    double userLng,
    Stop destinationStop,
    Map<String, List<Stop>> routeGroups,
  ) async {
    final List<Map<String, dynamic>> proximityOptions = [];
    
    print('🚀 RouteFinder: Using LOCAL DISTANCE ONLY for proximity-based options (no API calls)');
    
    for (final entry in routeGroups.entries) {
      final routeName = entry.key;
      final stopsOnRoute = entry.value;
      
      print('   📍 Route $routeName: Finding closest stop to user using local distance');
      
      // Find the stop CLOSEST TO USER on this route
      Stop? closestStopToUser;
      double minDistanceToUser = double.infinity;
      
      for (final stop in stopsOnRoute) {
        // Skip if this is the same as the destination stop
        if (stop.id == destinationStop.id) {
          print('      ⏭️ Skipping ${stop.name} - same as destination stop');
          continue;
        }
        
        // Calculate distance from user to this stop using LOCAL distance only
        final distanceToUser = DistanceCalculator.calculateDistance(
          userLat, userLng, stop.lat, stop.lng
        ) * 1.4; // Apply road network factor
        
        // Calculate distance from this stop to destination using Mapbox driving distance
        double distanceToDestination;
        try {
          final routeInfo = await MapboxDirectionsService.getRouteInfo(
            startLat: stop.lat,
            startLng: stop.lng,
            endLat: destinationStop.lat,
            endLng: destinationStop.lng,
            routeType: MapboxRouteType.driving,
          );
          
          if (routeInfo != null && routeInfo.distance > 0) {
            distanceToDestination = routeInfo.distance;
          } else {
            // Fallback to local distance if Mapbox fails
            distanceToDestination = DistanceCalculator.calculateDistance(
          stop.lat, stop.lng, destinationStop.lat, destinationStop.lng
            ) * 1.4; // Apply road network factor
          }
        } catch (e) {
          // Fallback to local distance if Mapbox fails
          distanceToDestination = DistanceCalculator.calculateDistance(
            stop.lat, stop.lng, destinationStop.lat, destinationStop.lng
          ) * 1.4; // Apply road network factor
        }
        
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
        // Calculate distance to destination for the selected stop using LOCAL distance
        final distanceToDestination = DistanceCalculator.calculateDistance(
          closestStopToUser.lat, closestStopToUser.lng, destinationStop.lat, destinationStop.lng
        ) * 1.4; // Apply road network factor
        
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
  
  /// Find transfer route using Mapbox driving profile distance
  Future<Stop?> _findTransferRoute(
    double userLat,
    double userLng,
    Stop destinationStop,
    List<Stop> allStops,
  ) async {
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
    
    return await _findNearestStop(userLat, userLng, transferStops);
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
    return DistanceCalculator.calculateTotalJourneyTime(
      walkingDistanceToStart: journey.walkingDistanceToStart,
      busDistance: journey.busDistance,
      walkingDistanceFromEnd: journey.walkingDistanceFromEnd,
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
