import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/data_service.dart';
import '../services/route_finder.dart';
import '../models/route.dart';
import '../widgets/route_info_card.dart';

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
      body: Column(
        children: [
          // Flutter Map
          Expanded(
            flex: 2,
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
            Expanded(
              flex: 1,
              child: RouteInfoCard(journey: _currentJourney!),
            ),
        ],
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
}
