import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/enhanced_location_service.dart';
import '../services/data_service.dart';
import '../services/route_finder.dart';
import '../models/route.dart';

import '../services/mapbox_service.dart';
import '../utils/distance_calculator.dart' as DistanceUtils;

class MapScreen extends StatefulWidget {
  final double? destinationLat;
  final double? destinationLng;
  final String? destinationName;

  const MapScreen({
    super.key,
    this.destinationLat,
    this.destinationLng,
    this.destinationName,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Journey? _currentJourney;
  bool _isLoadingRoute = false;
  String? _routeError;
  MapController? _mapController;
  List<LatLng> _routeCoordinates = [];
  bool _isMapReady = false;
  bool _hasMapError = false;
  List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Set edge-to-edge mode to prevent navigation bar interference
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Set system UI colors to match the screen
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    if (widget.destinationLat != null && widget.destinationLng != null) {
      _findRoute();
    }
  }

  Future<void> _findRoute() async {
    final locationService = context.read<EnhancedLocationService>();
    final routeFinder = context.read<RouteFinder>();
    
    final userPosition = locationService.currentPosition;
    if (userPosition == null) {
      setState(() {
        _routeError = 'User location not available';
      });
      return;
    }

    setState(() {
      _isLoadingRoute = true;
      _routeError = null;
    });

    try {
      final journey = await routeFinder.findBestRoute(
        userLat: userPosition.latitude,
        userLng: userPosition.longitude,
        destLat: widget.destinationLat!,
        destLng: widget.destinationLng!,
      );

      setState(() {
        _currentJourney = journey;
        _isLoadingRoute = false;
      });

      if (journey == null) {
        setState(() {
          _routeError = 'No route found to destination';
        });
      } else {
        // Get route directions from Mapbox
        await _loadRouteDirections(journey);
      }
    } catch (e) {
      setState(() {
        _routeError = 'Error finding route: $e';
        _isLoadingRoute = false;
      });
    }
  }

  Future<void> _loadRouteDirections(Journey journey) async {
    try {
      final routeDirections = await MapboxService.getRouteDirections(
        startLat: journey.startStop.lat,
        startLng: journey.startStop.lng,
        endLat: journey.endStop.lat,
        endLng: journey.endStop.lng,
        profile: 'driving',
      );

      if (routeDirections != null && routeDirections['geometry'] != null) {
        final geometry = routeDirections['geometry'];
        final coordinates = geometry['coordinates'] as List;
        _routeCoordinates = coordinates.map((coord) {
          return LatLng(coord[1].toDouble(), coord[0].toDouble());
        }).toList();

        // Add markers and route to map
        _addMarkersToMap();
        setState(() {
          _isMapReady = true;
        });
      }
    } catch (e) {
      print('Error loading route directions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.destinationName ?? 'Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              context.read<EnhancedLocationService>().getCurrentLocation();
              _centerMapOnUserLocation();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Flutter Map
          Expanded(
            flex: 2,
            child: _buildFlutterMap(),
          ),
          
          // Route information
          if (_isLoadingRoute)
            Container(
              padding: const EdgeInsets.all(16.0),
              child: const Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Finding best route...'),
                ],
              ),
            ),
          
          if (_routeError != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Route Error',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_routeError!),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _findRoute,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          
          if (_currentJourney != null)
            Expanded(
              flex: 1,
              child: _buildJourneyCard(),
            ),
        ],
      ),
    );
  }

  Widget _buildFlutterMap() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(
                        widget.destinationLat ?? 24.8607,
                        widget.destinationLng ?? 67.0011,
                      ),
                initialZoom: 13,
                onMapReady: () {
                  setState(() {
                    _isMapReady = true;
                  });
                  _addMarkersToMap();
                },
                onTap: (tapPosition, point) {
                  // Handle map taps if needed
                },
              ),
              children: [
                // OpenStreetMap tiles
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.redroute',
                ),
                // Route polyline
                if (_routeCoordinates.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routeCoordinates,
                        strokeWidth: 4,
                        color: const Color(0xFFE92929),
                      ),
                    ],
                  ),
                // Markers
                MarkerLayer(
                  markers: _markers,
                ),
              ],
            ),
            // Loading overlay
            if (!_isMapReady && !_hasMapError)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading map...'),
                    ],
                  ),
                ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyCard() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.route, color: const Color(0xFFE92929), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Journey Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF181111),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_calculateTotalTime()} min',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE92929),
                  ),
                ),
              ],
            ),
          ),
          
          // Journey info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildJourneyStep(
                    icon: Icons.directions_walk,
                    title: 'Walk to ${_currentJourney!.startStop.name}',
                    subtitle: '${(_currentJourney!.walkingDistanceToStart / 1000).toStringAsFixed(1)} km',
                  ),
                  _buildJourneyStep(
                    icon: Icons.directions_bus,
                    title: 'BRT Journey',
                    subtitle: '${_calculateBusTime()} min • ${_calculateBusDistance()} km',
                  ),
                  _buildJourneyStep(
                    icon: Icons.directions_walk,
                    title: 'Walk to destination',
                    subtitle: '${(_currentJourney!.walkingDistanceFromEnd / 1000).toStringAsFixed(1)} km',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/route-details',
                          arguments: _currentJourney,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE92929),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('View Full Details'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyStep({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE92929), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF886363),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addMarkersToMap() {
    final List<Marker> markers = [];
      
      // Add destination marker
      if (widget.destinationLat != null && widget.destinationLng != null) {
      markers.add(
        Marker(
          point: LatLng(widget.destinationLat!, widget.destinationLng!),
          width: 80,
          height: 80,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE92929),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  widget.destinationName ?? 'Destination',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          ),
        );
      }
      
      // Add journey markers if available
      if (_currentJourney != null) {
      // Start stop marker
      markers.add(
        Marker(
          point: LatLng(
              _currentJourney!.startStop.lat,
              _currentJourney!.startStop.lng,
            ),
          width: 80,
          height: 80,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_bus,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  _currentJourney!.startStop.name,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      
      // End stop marker
      markers.add(
        Marker(
          point: LatLng(
              _currentJourney!.endStop.lat,
              _currentJourney!.endStop.lng,
            ),
          width: 80,
          height: 80,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE92929),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_bus,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  _currentJourney!.endStop.name,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    setState(() {
      _markers = markers;
    });
  }

  void _centerMapOnUserLocation() {
    try {
      final locationService = context.read<EnhancedLocationService>();
      final position = locationService.currentPosition;
      
      if (position != null && _mapController != null) {
        _mapController!.move(
            LatLng(position.latitude, position.longitude),
          15,
        );
      }
    } catch (e) {
      print('Error centering map on user location: $e');
    }
  }

  int _calculateTotalTime() {
    if (_currentJourney == null) return 0;
    
    return DistanceUtils.DistanceCalculator.calculateJourneyTimeWithBykea(
      distanceToBusStop: _currentJourney!.walkingDistanceToStart,
      busJourneyDistance: _currentJourney!.busDistance,
      distanceFromBusStopToDestination: _currentJourney!.walkingDistanceFromEnd,
      requiresTransfer: _currentJourney!.requiresTransfer,
      departureTime: DateTime.now(),
    );
  }

  int _calculateBusTime() {
    if (_currentJourney == null) return 0;
    
    return DistanceUtils.DistanceCalculator.calculatePublicTransportTimeMinutes(
      distanceInMeters: _currentJourney!.busDistance,
      isBRT: true,
      requiresTransfer: _currentJourney!.requiresTransfer,
      departureTime: DateTime.now(),
    );
  }

  String _calculateBusDistance() {
    if (_currentJourney == null) return '0';
    
    return (_currentJourney!.busDistance / 1000).toStringAsFixed(1);
  }
}
