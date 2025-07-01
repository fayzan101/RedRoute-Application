import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import '../services/data_service.dart';
import '../services/route_finder.dart';
import '../models/route.dart';
import '../widgets/route_info_card.dart';
import '../utils/distance_calculator.dart';

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

  @override
  void initState() {
    super.initState();
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
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Map placeholder (since we can't use actual Mapbox in this environment)
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _buildMapPlaceholder(),
            ),
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
            Expanded(
              flex: 1,
              child: RouteInfoCard(journey: _currentJourney!),
            ),
        ],
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    return Consumer2<LocationService, DataService>(
      builder: (context, locationService, dataService, child) {
        final userPosition = locationService.currentPosition;
        final stops = dataService.stops;

        return Stack(
          children: [
            // Background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE3F2FD),
                    Color(0xFFF3E5F5),
                  ],
                ),
              ),
            ),
            
            // Map content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Map header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.map, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Interactive Map View',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Current location
                  if (userPosition != null)
                    _buildLocationCard(
                      icon: Icons.my_location,
                      title: 'Your Location',
                      subtitle: 'Lat: ${userPosition.latitude.toStringAsFixed(4)}, '
                          'Lng: ${userPosition.longitude.toStringAsFixed(4)}',
                      color: Colors.blue,
                    ),
                  
                  // Destination
                  if (widget.destinationLat != null && widget.destinationLng != null)
                    _buildLocationCard(
                      icon: Icons.place,
                      title: widget.destinationName ?? 'Destination',
                      subtitle: 'Lat: ${widget.destinationLat!.toStringAsFixed(4)}, '
                          'Lng: ${widget.destinationLng!.toStringAsFixed(4)}',
                      color: Colors.red,
                    ),
                  
                  // Journey info
                  if (_currentJourney != null) ...[
                    const SizedBox(height: 16),
                    _buildJourneyOverview(),
                  ],
                  
                  // Nearby stops
                  if (userPosition != null && stops.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildNearbyStops(userPosition.latitude, userPosition.longitude, stops),
                  ],
                ],
              ),
            ),
            
            // Map controls
            Positioned(
              bottom: 16,
              right: 16,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'zoom_in',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Zoom In')),
                      );
                    },
                    child: const Icon(Icons.zoom_in),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'zoom_out',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Zoom Out')),
                      );
                    },
                    child: const Icon(Icons.zoom_out),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLocationCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
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
        ],
      ),
    );
  }

  Widget _buildJourneyOverview() {
    if (_currentJourney == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                'Route Overview',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.directions_bus, size: 16, color: Colors.green.shade600),
              const SizedBox(width: 4),
              Text(
                '${_currentJourney!.startStop.name} → ${_currentJourney!.endStop.name}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.straighten, size: 16, color: Colors.green.shade600),
              const SizedBox(width: 4),
              Text(
                'Total: ${DistanceCalculator.formatDistance(_currentJourney!.totalDistance)}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          if (_currentJourney!.requiresTransfer)
            Row(
              children: [
                Icon(Icons.swap_horiz, size: 16, color: Colors.orange.shade600),
                const SizedBox(width: 4),
                Text(
                  'Transfer at ${_currentJourney!.transferStop?.name ?? "Unknown"}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildNearbyStops(double userLat, double userLng, List stops) {
    // Find nearby stops (within 2km)
    final nearbyStops = stops.where((stop) {
      final distance = DistanceCalculator.calculateDistance(
        userLat,
        userLng,
        stop.lat,
        stop.lng,
      );
      return distance <= 2000; // 2km
    }).take(3).toList();

    if (nearbyStops.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.near_me, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Nearby BRT Stops',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...nearbyStops.map((stop) {
            final distance = DistanceCalculator.calculateDistance(
              userLat,
              userLng,
              stop.lat,
              stop.lng,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.bus_alert, size: 16, color: Colors.blue.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${stop.name} (${DistanceCalculator.formatDistance(distance)})',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
