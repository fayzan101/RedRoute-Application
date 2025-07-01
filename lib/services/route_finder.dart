import '../models/stop.dart';
import '../models/route.dart';
import '../utils/distance_calculator.dart';
import 'data_service.dart';

class RouteFinder {
  final DataService _dataService;
  
  RouteFinder(this._dataService);
  
  /// Find the best journey from user location to destination
  Future<Journey?> findBestRoute({
    required double userLat,
    required double userLng,
    required double destLat,
    required double destLng,
  }) async {
    await _dataService.loadBRTData();
    
    final stops = _dataService.stops;
    if (stops.isEmpty) return null;
    
    // Find nearest stop to destination
    final nearestToDestination = _findNearestStop(destLat, destLng, stops);
    if (nearestToDestination == null) return null;
    
    // Find best boarding stop for user
    final bestBoardingStop = _findBestBoardingStop(
      userLat,
      userLng,
      nearestToDestination,
      stops,
    );
    if (bestBoardingStop == null) return null;
    
    // Calculate journey details
    final journey = _createJourney(
      userLat: userLat,
      userLng: userLng,
      destLat: destLat,
      destLng: destLng,
      boardingStop: bestBoardingStop,
      destinationStop: nearestToDestination,
    );
    
    return journey;
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
    
    // Find nearest viable stop to user
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
  
  Journey _createJourney({
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
    
    final busDistance = DistanceCalculator.calculateDistance(
      boardingStop.lat,
      boardingStop.lng,
      destinationStop.lat,
      destinationStop.lng,
    );
    
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
}
