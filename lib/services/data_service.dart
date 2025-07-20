import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/stop.dart';
import '../models/route.dart';

class DataService extends ChangeNotifier {
  List<Stop>? _stops;
  List<BusRoute>? _routes;
  
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
              print('Error parsing stop: $e');
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
    
    // Create route objects
    _routes = routeStopsMap.entries.map((entry) {
      // Sort stops by a logical order (you might want to implement a better sorting logic)
      final sortedStops = entry.value..sort((a, b) => a.id.compareTo(b.id));
      
      return BusRoute(
        name: entry.key,
        stops: sortedStops,
        color: _getRouteColor(entry.key),
      );
    }).toList();
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
  
  BusRoute? getRouteByName(String name) {
    return _routes?.firstWhere(
      (route) => route.name == name,
      orElse: () => BusRoute(name: '', stops: []),
    );
  }
}
