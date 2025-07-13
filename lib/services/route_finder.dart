import 'package:flutter/foundation.dart';
import '../models/stop.dart';
import '../models/route.dart';
import '../utils/distance_calculator.dart';
import 'data_service.dart';
import 'mapbox_service.dart';

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
    
    // Find nearest stop to destination
    final nearestToDestination = _findNearestStop(destLat, destLng, stops);
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
    
    // Find nearest stop to destination
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
    
    // For each route, find the best boarding stop
    final List<Map<String, dynamic>> routeOptions = [];
    
    for (final entry in routeGroups.entries) {
      final routeName = entry.key;
      final stopsOnRoute = entry.value;
      
      // Find the best stop on this route
      Stop? bestStopOnRoute;
      double bestScore = double.infinity;
      
      for (final stop in stopsOnRoute) {
        final distanceToUser = DistanceCalculator.calculateDistance(
          userLat, userLng, stop.lat, stop.lng
        );
        
        final distanceToDestination = DistanceCalculator.calculateDistance(
          stop.lat, stop.lng, destinationStop.lat, destinationStop.lng
        );
        
        // Score based on: 70% route efficiency + 30% accessibility
        final routeEfficiency = distanceToDestination / 1000;
        final accessibility = distanceToUser / 1000;
        final score = (routeEfficiency * 0.7) + (accessibility * 0.3);
        
        if (score < bestScore) {
          bestScore = score;
          bestStopOnRoute = stop;
        }
      }
      
      if (bestStopOnRoute != null) {
        routeOptions.add({
          'route': routeName,
          'stop': bestStopOnRoute,
          'score': bestScore,
          'distanceToUser': DistanceCalculator.calculateDistance(
            userLat, userLng, bestStopOnRoute.lat, bestStopOnRoute.lng
          ),
          'distanceToDestination': DistanceCalculator.calculateDistance(
            bestStopOnRoute.lat, bestStopOnRoute.lng, destinationStop.lat, destinationStop.lng
          ),
        });
      }
    }
    
    // Sort by score and return top options
    routeOptions.sort((a, b) => a['score'].compareTo(b['score']));
    return routeOptions.take(maxOptions).toList();
  }
  
  Stop? _findNearestStop(double lat, double lng, List<Stop> stops) {
    if (stops.isEmpty) return null;
    
    Stop? nearest;
    double minDistance = double.infinity;
    
    for (final stop in stops) {
      try {
        final distance = DistanceCalculator.calculateDistance(
          lat,
          lng,
          stop.lat,
          stop.lng,
        );
        
        if (distance < minDistance) {
          minDistance = distance;
          nearest = stop;
        }
      } catch (e) {
        // Skip invalid stop data
        continue;
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
    final viableStops = allStops.where((stop) {
      return stop.routes.any((route) => destinationStop.routes.contains(route));
    }).toList();
    
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
    
    // For each route, find the best boarding stop
    final List<Map<String, dynamic>> routeOptions = [];
    
    print('🛣️ RouteFinder: Analyzing ${routeGroups.length} routes to destination');
    
    for (final entry in routeGroups.entries) {
      final routeName = entry.key;
      final stopsOnRoute = entry.value;
      
      print('   📍 Route $routeName: ${stopsOnRoute.length} stops available');
      
      // Find the best stop on this route (considering both distance to user and route efficiency)
      Stop? bestStopOnRoute;
      double bestScore = double.infinity;
      
      for (final stop in stopsOnRoute) {
        // Skip if this is the same as the destination stop (no bus journey needed)
        if (stop.id == destinationStop.id) {
          print('      ⏭️ Skipping ${stop.name} - same as destination stop');
          continue;
        }
        
        // Calculate distance from user to this stop (with road network adjustment)
        final distanceToUser = DistanceCalculator.calculateDistance(
          userLat, userLng, stop.lat, stop.lng
        );
        
        // Calculate distance from this stop to destination stop (with road network adjustment)
        final distanceToDestination = DistanceCalculator.calculateDistance(
          stop.lat, stop.lng, destinationStop.lat, destinationStop.lng
        );
        
        // Score based on: 70% route efficiency (shorter bus journey) + 30% accessibility (distance to user)
        // Lower score is better
        final routeEfficiency = distanceToDestination / 1000; // Convert to km for better scaling
        final accessibility = distanceToUser / 1000; // Convert to km for better scaling
        final score = (routeEfficiency * 0.7) + (accessibility * 0.3);
        
        print('      🚏 ${stop.name}: User distance ${DistanceCalculator.formatDistance(distanceToUser)}, '
              'Route distance ${DistanceCalculator.formatDistance(distanceToDestination)}, '
              'Score ${score.toStringAsFixed(2)}');
        
        if (score < bestScore) {
          bestScore = score;
          bestStopOnRoute = stop;
        }
      }
      
      if (bestStopOnRoute != null) {
        routeOptions.add({
          'route': routeName,
          'stop': bestStopOnRoute,
          'score': bestScore,
          'distanceToUser': DistanceCalculator.calculateDistance(
            userLat, userLng, bestStopOnRoute.lat, bestStopOnRoute.lng
          ),
          'distanceToDestination': DistanceCalculator.calculateDistance(
            bestStopOnRoute.lat, bestStopOnRoute.lng, destinationStop.lat, destinationStop.lng
          ),
        });
        
        print('      ✅ Best on $routeName: ${bestStopOnRoute.name} (Score: ${bestScore.toStringAsFixed(2)})');
      }
    }
    
    // Sort by score (best first)
    routeOptions.sort((a, b) => a['score'].compareTo(b['score']));
    
    print('🏆 RouteFinder: Route options ranked by score:');
    for (int i = 0; i < routeOptions.length; i++) {
      final option = routeOptions[i];
      print('   ${i + 1}. ${option['route']} from ${option['stop'].name} '
            '(Score: ${option['score'].toStringAsFixed(2)})');
    }
    
    // Return the best option
    if (routeOptions.isNotEmpty) {
      print('🚌 RouteFinder: Selected best route: ${routeOptions.first['route']} '
            'from ${routeOptions.first['stop'].name} '
            '(Score: ${routeOptions.first['score'].toStringAsFixed(2)}, '
            'User distance: ${DistanceCalculator.formatDistance(routeOptions.first['distanceToUser'])}, '
            'Route distance: ${DistanceCalculator.formatDistance(routeOptions.first['distanceToDestination'])})');
      
      return routeOptions.first['stop'] as Stop;
    }
    
    // Check if destination is very close to a BRT stop (within 500m)
    final distanceToDestinationStop = DistanceCalculator.calculateDistance(
      userLat, userLng, destinationStop.lat, destinationStop.lng
    );
    
    if (distanceToDestinationStop < 500) {
      print('🚶 RouteFinder: Destination is very close to BRT stop (${DistanceCalculator.formatDistance(distanceToDestinationStop)}). Suggesting walking instead of bus.');
      // Return null to indicate walking is better than bus
      return null;
    }
    
    // Fallback to nearest viable stop if no route-based option found
    return _findNearestStop(userLat, userLng, viableStops);
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
    
    if (walkingDistanceFromEnd < 500) {
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
    if (walkingDistanceFromEnd < 500) {
      buffer.writeln('$finalStepNumber. Walk ${DistanceCalculator.formatDistance(walkingDistanceFromEnd)} to your destination');
    } else if (walkingDistanceFromEnd < 2000) {
      buffer.writeln('$finalStepNumber. Take a rickshaw (${DistanceCalculator.formatDistance(walkingDistanceFromEnd)}) to your destination');
    } else {
      buffer.writeln('$finalStepNumber. Take Bykea/Careem (${DistanceCalculator.formatDistance(walkingDistanceFromEnd)}) to your destination');
    }
    
    return buffer.toString();
  }
  
  int _calculateTotalJourneyTime(Journey journey) {
    final busDistance = journey.totalDistance - journey.walkingDistanceToStart - journey.walkingDistanceFromEnd;
    
    return DistanceCalculator.calculateJourneyTimeWithBykea(
      distanceToBusStop: journey.walkingDistanceToStart,
      busJourneyDistance: busDistance,
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
