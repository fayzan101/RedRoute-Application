import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/data_service.dart';
import '../services/route_finder.dart';
import '../models/route.dart';
import '../services/geocoding_service.dart';
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
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
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
    final locationService = context.read<LocationService>();
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
      }
    } catch (e) {
      setState(() {
        _routeError = 'Error finding route: $e';
        _isLoadingRoute = false;
      });
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
              context.read<LocationService>().getCurrentLocation();
              _centerMapOnUserLocation();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
        children: [
          // Flutter Map
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6, // Fixed height for map
            child: _buildFlutterMap(),
          ),
          
          // Route information
          if (_isLoadingRoute)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
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
              Column(
                children: [
                  // First Card: Entire Journey Details
                  Card(
                    margin: const EdgeInsets.all(16.0),
                    child: InkWell(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/route-details',
                          arguments: _currentJourney,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.directions,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Entire Journey Details',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Current Location
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
            Expanded(
                                  child: Text(
                                    'Current Location',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 28),
                              child: Consumer<LocationService>(
                                builder: (context, locationService, child) {
                                  final position = locationService.currentPosition;
                                  if (position != null) {
                                    return FutureBuilder<String?>(
                                      future: GeocodingService.getAddressFromCoordinates(
                                        position.latitude,
                                        position.longitude,
                                      ),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData && snapshot.data != null) {
                                          return Text(
                                            snapshot.data!,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          );
                                        }
                                        return Text(
                                          'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        );
                                      },
                                    );
                                  }
                                  return const Text(
                                    'Location not available',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Destination
                            Row(
                              children: [
                                Icon(
                                  Icons.place,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Destination',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 28),
                              child: Text(
                                widget.destinationName ?? 'Unknown destination',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Journey Summary
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                                                     _buildJourneyItem(
                                     icon: Icons.straighten,
                                     label: 'Total Distance',
                                     value: DistanceUtils.DistanceCalculator.formatDistance(_currentJourney!.totalDistance),
                                     color: Colors.blue,
                                   ),
                                  _buildJourneyItem(
                                    icon: Icons.access_time,
                                    label: 'Total Time',
                                    value: '${_calculateTotalTime()}min',
                                    color: Colors.green,
                                  ),
                                  _buildJourneyItem(
                                    icon: Icons.directions_bus,
                                    label: 'Total Routes',
                                    value: _currentJourney!.routes.length.toString(),
                                    color: Colors.purple,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16), // Gap between first and second card
                  
                  // Second Card: Location to Bus Stop
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: InkWell(
                      onTap: () {
                        _showBusStopDetails();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.directions_bus,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Location to Bus Stop',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Nearest Bus Stop Info
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Nearest BRT Stop',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 28),
                              child: Text(
                                _currentJourney!.startStop.name,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Walking Distance
                            Row(
                              children: [
                                Icon(
                                  Icons.directions_walk,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Walking Distance',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 28),
                                                             child: Text(
                                 DistanceUtils.DistanceCalculator.formatDistance(_currentJourney!.walkingDistanceToStart),
                                 style: const TextStyle(
                                   color: Colors.grey,
                                   fontSize: 12,
                                 ),
                               ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Suggestions
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.lightbulb_outline,
                                        color: Colors.orange.shade700,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Suggestions',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _getBusStopSuggestions(),
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16), // Gap between second and third card
                  
                  // Third Card: Bus Stop to Destination
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: InkWell(
                      onTap: () {
                        _showDestinationDetails();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.place,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Bus Stop to Destination',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Destination Bus Stop Info
                            Row(
                              children: [
                                Icon(
                                  Icons.directions_bus,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Destination BRT Stop',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 28),
                              child: Text(
                                _currentJourney!.endStop.name,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Distance to Final Destination
                            Row(
                              children: [
                                Icon(
                                  Icons.straighten,
                                  color: Colors.purple,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Distance to Destination',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 28),
                              child: Text(
                                DistanceUtils.DistanceCalculator.formatDistance(_currentJourney!.walkingDistanceFromEnd),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Suggestions
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.purple.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.lightbulb_outline,
                                        color: Colors.purple.shade700,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Suggestions',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple.shade700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _getDestinationSuggestions(),
                                    style: TextStyle(
                                      color: Colors.purple.shade700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 24), // Gap between cards and map
            
            // Map Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              height: 300,
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
                child: _buildFlutterMap(),
              ),
            ),
            
            const SizedBox(height: 32), // Bottom padding for better scrolling
          ],
        ),
      ),
    );
  }

  Widget _buildFlutterMap() {
    return Consumer2<LocationService, DataService>(
      builder: (context, locationService, dataService, child) {
        final userPosition = locationService.currentPosition;
        final stops = dataService.stops;

        // Determine center position
        LatLng centerPosition;
        if (userPosition != null) {
          centerPosition = LatLng(userPosition.latitude, userPosition.longitude);
        } else {
          centerPosition = const LatLng(24.8607, 67.0011); // Karachi center
        }

        // Create markers
        List<Marker> markers = [];
        
        // Add user location marker
        if (userPosition != null) {
          markers.add(
            Marker(
              point: LatLng(userPosition.latitude, userPosition.longitude),
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.my_location,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          );
        }

        // Add destination marker
        if (widget.destinationLat != null && widget.destinationLng != null) {
          markers.add(
            Marker(
              point: LatLng(widget.destinationLat!, widget.destinationLng!),
              width: 40,
              height: 40,
              child: Container(
                    decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.place,
                      color: Colors.white,
                  size: 20,
                            ),
                          ),
                        ),
          );
        }

        // Add BRT stop markers
        for (final stop in stops.take(20)) { // Limit to 20 stops for performance
          markers.add(
            Marker(
              point: LatLng(stop.lat, stop.lng),
              width: 30,
              height: 30,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: const Icon(
                  Icons.directions_bus,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          );
        }

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: centerPosition,
            initialZoom: 12.0,
            minZoom: 8.0,
            maxZoom: 18.0,
          ),
                children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.redroute.karachi',
              maxZoom: 19,
            ),
            MarkerLayer(markers: markers),
            if (_currentJourney != null) _buildRoutePolylines(),
          ],
        );
      },
    );
  }

  Widget _buildRoutePolylines() {
    if (_currentJourney == null) return const SizedBox();

    final List<LatLng> routePoints = [];
    
    // Add route points from journey
    for (final route in _currentJourney!.routes) {
      for (final stop in route.stops) {
        routePoints.add(LatLng(stop.lat, stop.lng));
      }
    }

    return PolylineLayer(
      polylines: [
        Polyline(
          points: routePoints,
          color: Theme.of(context).primaryColor,
          strokeWidth: 4.0,
        ),
      ],
    );
  }

  void _centerMapOnUserLocation() {
    final locationService = context.read<LocationService>();
    final userPosition = locationService.currentPosition;
    
    if (userPosition != null) {
      _mapController.move(
        LatLng(userPosition.latitude, userPosition.longitude),
        14.0,
      );
    }
  }

  Widget _buildJourneyItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  int _calculateTotalTime() {
    if (_currentJourney == null) return 0;
    
    // Calculate total journey time: Bykea to bus stop + bus journey + final leg to destination
    final busDistance = _currentJourney!.totalDistance - 
                       _currentJourney!.walkingDistanceToStart - 
                       _currentJourney!.walkingDistanceFromEnd;
    
    return DistanceUtils.DistanceCalculator.calculateJourneyTimeWithBykea(
      distanceToBusStop: _currentJourney!.walkingDistanceToStart,
      busJourneyDistance: busDistance,
      distanceFromBusStopToDestination: _currentJourney!.walkingDistanceFromEnd,
      requiresTransfer: _currentJourney!.requiresTransfer,
      departureTime: DateTime.now(),
    );
  }

  String _getBusStopSuggestions() {
    if (_currentJourney == null) return '';
    
    final walkingDistance = _currentJourney!.walkingDistanceToStart;
    final suggestions = <String>[];
    
    if (walkingDistance > 1000) {
      suggestions.add('• Consider using a rickshaw to reach the bus stop');
    }
    if (walkingDistance > 500) {
      suggestions.add('• Walk briskly to save time');
    }
    if (_currentJourney!.requiresTransfer) {
      suggestions.add('• Plan for 5 minutes transfer time');
    }
    suggestions.add('• Arrive 2-3 minutes before bus arrival');
    suggestions.add('• Keep your BRT card ready');
    
    return suggestions.join('\n');
  }

  void _showBusStopDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Bus Stop Details',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Location to Bus Stop
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'From Current Location',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              Row(
                                children: [
                                  Icon(Icons.location_on, color: Colors.blue, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Consumer<LocationService>(
                                      builder: (context, locationService, child) {
                                        final position = locationService.currentPosition;
                                        if (position != null) {
                                          return FutureBuilder<String?>(
                                            future: GeocodingService.getAddressFromCoordinates(
                                              position.latitude,
                                              position.longitude,
                                            ),
                                            builder: (context, snapshot) {
                                              return Text(
                                                snapshot.data ?? 'Current Location',
                                                style: const TextStyle(fontSize: 14),
                                              );
                                            },
                                          );
                                        }
                                        return const Text('Location not available');
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 8),
                              
                              Row(
                                children: [
                                  Icon(Icons.directions_walk, color: Colors.green, size: 20),
                                  const SizedBox(width: 8),
                                                                     Expanded(
                                     child: Text(
                                       '${DistanceUtils.DistanceCalculator.formatDistance(_currentJourney!.walkingDistanceToStart)} walking',
                                       style: const TextStyle(fontSize: 14),
                                     ),
                                   ),
                                ],
                              ),
                              
                              const SizedBox(height: 8),
                              
                              Row(
                                children: [
                                  Icon(Icons.directions_bus, color: Colors.red, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'To ${_currentJourney!.startStop.name}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Bus Stop Information
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bus Stop Information',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              Text(
                                'Name: ${_currentJourney!.startStop.name}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              
                              Text(
                                'Routes: ${_currentJourney!.routes.map((r) => r.name).join(', ')}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              
                              Text(
                                'Facilities: Covered shelter, Seating, Real-time updates',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Suggestions
                      Card(
                        color: Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.lightbulb_outline, color: Colors.orange.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Travel Tips',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              Text(
                                _getBusStopSuggestions(),
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDestinationSuggestions() {
    if (_currentJourney == null) return '';
    
    final distanceToDestination = _currentJourney!.walkingDistanceFromEnd;
    final suggestions = <String>[];
    
    if (distanceToDestination < 500) {
      suggestions.add('• Short walk to your destination');
      suggestions.add('• Enjoy the walk and save money');
    } else if (distanceToDestination < 2000) {
      suggestions.add('• Consider taking a rickshaw');
      suggestions.add('• Walking will take 10-15 minutes');
    } else {
      suggestions.add('• Take Bykea or rickshaw to destination');
      suggestions.add('• Walking will take 20+ minutes');
    }
    
    suggestions.add('• Keep your belongings secure');
    suggestions.add('• Follow local traffic rules');
    
    return suggestions.join('\n');
  }

  void _showDestinationDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Destination Details',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bus Stop to Destination
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'From Bus Stop to Destination',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              Row(
                                children: [
                                  Icon(Icons.directions_bus, color: Colors.red, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Get off at ${_currentJourney!.endStop.name}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 8),
                              
                              Row(
                                children: [
                                  Icon(Icons.straighten, color: Colors.purple, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${DistanceUtils.DistanceCalculator.formatDistance(_currentJourney!.walkingDistanceFromEnd)} to destination',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 8),
                              
                              Row(
                                children: [
                                  Icon(Icons.place, color: Colors.red, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.destinationName ?? 'Your destination',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Transport Options
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Transport Options',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              _buildTransportOption(
                                icon: Icons.directions_walk,
                                title: 'Walk',
                                subtitle: '${_calculateWalkingTime()} min',
                                distance: _currentJourney!.walkingDistanceFromEnd,
                              ),
                              
                              const SizedBox(height: 8),
                              
                              _buildTransportOption(
                                icon: Icons.directions_car,
                                title: 'Rickshaw',
                                subtitle: '${_calculateRickshawTime()} min',
                                distance: _currentJourney!.walkingDistanceFromEnd,
                              ),
                              
                              const SizedBox(height: 8),
                              
                              _buildTransportOption(
                                icon: Icons.motorcycle,
                                title: 'Bykea',
                                subtitle: '${_calculateBykeaTime()} min',
                                distance: _currentJourney!.walkingDistanceFromEnd,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Suggestions
                      Card(
                        color: Colors.purple.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.lightbulb_outline, color: Colors.purple.shade700),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Travel Tips',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              Text(
                                _getDestinationSuggestions(),
                                style: TextStyle(
                                  color: Colors.purple.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required double distance,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Text(
          DistanceUtils.DistanceCalculator.formatDistance(distance),
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  int _calculateWalkingTime() {
    if (_currentJourney == null) return 0;
    return DistanceUtils.DistanceCalculator.calculateWalkingTimeMinutes(
      _currentJourney!.walkingDistanceFromEnd,
    );
  }

  int _calculateRickshawTime() {
    if (_currentJourney == null) return 0;
    return DistanceUtils.DistanceCalculator.calculateDrivingTimeMinutes(
      distanceInMeters: _currentJourney!.walkingDistanceFromEnd,
      vehicleType: 'rickshaw',
    );
  }

  int _calculateBykeaTime() {
    if (_currentJourney == null) return 0;
    return DistanceUtils.DistanceCalculator.calculateDrivingTimeMinutes(
      distanceInMeters: _currentJourney!.walkingDistanceFromEnd,
      vehicleType: 'bykea',
    );
  }
}
