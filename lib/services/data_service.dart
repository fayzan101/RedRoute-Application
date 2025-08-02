import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/stop.dart';
import '../models/route.dart';

class DataService extends ChangeNotifier {
  List<Stop>? _stops;
  List<BusRoute>? _routes;
  Map<String, dynamic>? _cachedRouteData; // Cache for route sequence data
  
  List<Stop> get stops => _stops ?? [];
  List<BusRoute> get routes => _routes ?? [];

  Future<void> loadBRTData() async {
    if (_stops != null) return; // Already loaded
    
    try {
      // Try loading from the new bus routes file first
      String response;
      try {
        response = await rootBundle.loadString('assets/bus_routes.json');
      } catch (e) {
        // Fallback to old file name
        response = await rootBundle.loadString('assets/brt_stops_corrected.json');
      }
      
      final Map<String, dynamic> data = json.decode(response);
      
      // Cache the route data for sequence ordering
      _cachedRouteData = data;
      
      // Handle both new and old data formats
      final List<Stop> allStops = [];
      
      if (data.containsKey('routes')) {
        // New format with routes
        final routes = data['routes'] as List<dynamic>;
        
        for (final route in routes) {
          final routeStops = route['stops'] as List<dynamic>;
          for (final stopJson in routeStops) {
            try {
              final stop = Stop.fromJson(stopJson);
              // Avoid duplicates
              if (!allStops.any((s) => s.id == stop.id)) {
                allStops.add(stop);
              }
            } catch (e) {
              
              continue;
            }
          }
        }
      } else if (data.containsKey('stops')) {
        // Direct stops format
        final stops = data['stops'] as List<dynamic>;
        for (final stopJson in stops) {
          try {
            final stop = Stop.fromJson(stopJson);
            allStops.add(stop);
          } catch (e) {
            
            continue;
          }
        }
      }
      
      if (allStops.isEmpty) {
        throw Exception('No valid BRT stops found in data file');
      }
      
      _stops = allStops;
      _generateRoutes();
      
      // Debug: Check if Fast University is loaded
      final fastUniversity = allStops.where((stop) => 
        stop.name.toLowerCase().contains('fast') || 
        stop.name.toLowerCase().contains('university')
      ).toList();
      
      if (fastUniversity.isNotEmpty) {
        
      }
      
      notifyListeners();
      
      
    } catch (e) {
     
      throw Exception('Failed to load BRT data: $e');
    }
  }
  
  void _generateRoutes() {
    if (_stops == null) return;
    
    final Map<String, List<Stop>> routeStopsMap = {};
    
    // Group stops by route
    for (final stop in _stops!) {
      for (final routeName in stop.routes) {
        routeStopsMap.putIfAbsent(routeName, () => []).add(stop);
      }
    }
    
    // Create route objects with proper sequence order
    _routes = routeStopsMap.entries.map((entry) {
      final routeName = entry.key;
      final stops = entry.value;
      
      // IMPROVED: Sort stops by their actual sequence in the route
      // This preserves the order from the JSON data instead of sorting by ID
      final sortedStops = _sortStopsByRouteSequence(routeName, stops);
      
      return BusRoute(
        name: routeName,
        stops: sortedStops,
        color: _getRouteColor(routeName),
      );
    }).toList();
  }
  
  /// Sort stops by their actual sequence in the route based on JSON data order
  List<Stop> _sortStopsByRouteSequence(String routeName, List<Stop> stops) {
    // Try to load the original route data to get proper sequence
    try {
      // Load the JSON data to get the original stop sequence
      final routeData = _loadRouteDataFromJson();
      final routeInfo = routeData['routes']?.firstWhere(
        (route) => route['routeName'] == routeName,
        orElse: () => null,
      );
      
      if (routeInfo != null) {
        final routeStops = routeInfo['stops'] as List<dynamic>;
        final stopIdOrder = routeStops.map((stop) => stop['stopId'] as String).toList();
        
        // Sort stops based on their position in the original route sequence
        stops.sort((a, b) {
          final aIndex = stopIdOrder.indexOf(a.id);
          final bIndex = stopIdOrder.indexOf(b.id);
          
          // If both stops are in the sequence, sort by their position
          if (aIndex != -1 && bIndex != -1) {
            return aIndex.compareTo(bIndex);
          }
          // If only one is in the sequence, prioritize the one that is
          if (aIndex != -1) return -1;
          if (bIndex != -1) return 1;
          // If neither is in the sequence, sort by ID as fallback
          return a.id.compareTo(b.id);
        });
      }
    } catch (e) {
      print('⚠️ DataService: Error sorting stops for route $routeName: $e');
      // Fallback to ID sorting if JSON parsing fails
      stops.sort((a, b) => a.id.compareTo(b.id));
    }
    
    return stops;
  }
  
  /// Load route data from JSON for proper sequence ordering
  Map<String, dynamic> _loadRouteDataFromJson() {
    // Use cached route data if available
    if (_cachedRouteData != null) {
      return _cachedRouteData!;
    }
    
    // Fallback to empty map if no cached data
    return {'routes': []};
  }
  
  String _getRouteColor(String routeName) {
    // Define colors for different routes
    final Map<String, String> routeColors = {
      'Route 1': '#E53E3E',
      'Route 2': '#3182CE',
      'Route 3': '#38A169',
      'Route 4': '#D69E2E',
      'Route 5': '#805AD5',
      'Route 6': '#DD6B20',
      'Route 7': '#319795',
      'Route 8': '#E53E3E',
      'Route 9': '#3182CE',
      'Route 10': '#38A169',
    };
    
    return routeColors[routeName] ?? '#E53E3E';
  }
  
  List<Stop> searchStops(String query) {
    if (_stops == null || query.isEmpty) return [];
    
    final lowercaseQuery = query.toLowerCase();
    return _stops!
        .where((stop) => stop.name.toLowerCase().contains(lowercaseQuery))
        .toList();
  }
  
  Stop? findStopById(String id) {
    return _stops?.firstWhere(
      (stop) => stop.id == id,
      orElse: () => Stop(id: '', name: '', lat: 0, lng: 0, routes: []),
    );
  }
  
  List<String> getAllRouteNames() {
    return _routes?.map((route) => route.name).toList() ?? [];
  }

  /// Get route names sorted in specific order: regular routes (1-13) first, then EV routes (1-5)
  List<String> getSortedRouteNames() {
    if (_routes == null) return [];
    
    final List<String> regularRoutes = [];
    final List<String> evRoutes = [];
    
    // Separate regular routes and EV routes
    for (final route in _routes!) {
      if (route.name.startsWith('EV-')) {
        evRoutes.add(route.name);
      } else {
        // Regular routes are just numbers
        regularRoutes.add(route.name);
      }
    }
    
    // Sort regular routes by number (1, 2, 3, 4, 8, 9, 10, 11, 12, 13)
    regularRoutes.sort((a, b) {
      final aNum = int.tryParse(a) ?? 0;
      final bNum = int.tryParse(b) ?? 0;
      return aNum.compareTo(bNum);
    });
    
    // Sort EV routes by number (EV-1, EV-2, EV-3, EV-4, EV-5)
    evRoutes.sort((a, b) {
      final aNum = int.tryParse(a.replaceAll('EV-', '')) ?? 0;
      final bNum = int.tryParse(b.replaceAll('EV-', '')) ?? 0;
      return aNum.compareTo(bNum);
    });
    
    // Combine: regular routes first, then EV routes
    return [...regularRoutes, ...evRoutes];
  }

  /// Get routes sorted in specific order: regular routes (1-13) first, then EV routes (1-5)
  List<BusRoute> getSortedRoutes() {
    if (_routes == null) return [];
    
    final sortedRouteNames = getSortedRouteNames();
    final List<BusRoute> sortedRoutes = [];
    
    // Create sorted list based on the sorted route names
    for (final routeName in sortedRouteNames) {
      final route = _routes!.firstWhere(
        (route) => route.name == routeName,
        orElse: () => BusRoute(name: routeName, stops: []),
      );
      if (route.name.isNotEmpty) {
        sortedRoutes.add(route);
      }
    }
    
    return sortedRoutes;
  }
  
  BusRoute? getRouteByName(String name) {
    return _routes?.firstWhere(
      (route) => route.name == name,
      orElse: () => BusRoute(name: '', stops: []),
    );
  }
}
