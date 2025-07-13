import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/route.dart';
import '../utils/distance_calculator.dart';
import '../services/mapbox_service.dart';
import '../services/enhanced_location_service.dart';
import '../services/route_finder.dart';
import '../screens/map_screen.dart';

class RouteDetailsScreen extends StatefulWidget {
  final Journey? journey;
  final double? destinationLat;
  final double? destinationLng;
  final String? destinationName;
  
  const RouteDetailsScreen({
    super.key, 
    this.journey,
    this.destinationLat,
    this.destinationLng,
    this.destinationName,
  });

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  Map<String, dynamic>? journeyDetails;
  bool isLoading = true;
  Journey? _foundJourney;

  @override
  void initState() {
    super.initState();
    if (widget.journey != null) {
      _loadJourneyDetails();
    } else if (widget.destinationLat != null && widget.destinationLng != null) {
      _findRoute();
    }
  }

  Future<void> _findRoute() async {
    final locationService = context.read<EnhancedLocationService>();
    final routeFinder = context.read<RouteFinder>();
    
    final userPosition = locationService.currentPosition;
    if (userPosition == null) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for location to be detected first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final journey = await routeFinder.findBestRoute(
        userLat: userPosition.latitude,
        userLng: userPosition.longitude,
        destLat: widget.destinationLat!,
        destLng: widget.destinationLng!,
      );

      if (journey != null) {
        setState(() {
          _foundJourney = journey;
        });
        await _loadJourneyDetails(journey);
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No route found to destination'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finding route: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadJourneyDetails([Journey? journey]) async {
    final currentJourney = journey ?? widget.journey;
    if (currentJourney != null) {
      try {
        // Get journey details
        final details = await MapboxService.getJourneyDetails(
          startLat: currentJourney.startStop.lat,
          startLng: currentJourney.startStop.lng,
          endLat: currentJourney.endStop.lat,
          endLng: currentJourney.endStop.lng,
          busStopLat: currentJourney.startStop.lat,
          busStopLng: currentJourney.startStop.lng,
          destinationStopLat: currentJourney.endStop.lat,
          destinationStopLng: currentJourney.endStop.lng,
        );

        // Get traffic information
        final trafficInfo = await MapboxService.getTrafficInfo(
          startLat: currentJourney.startStop.lat,
          startLng: currentJourney.startStop.lng,
          endLat: currentJourney.endStop.lat,
          endLng: currentJourney.endStop.lng,
        );

        setState(() {
          journeyDetails = details;
          if (trafficInfo != null) {
            journeyDetails!['trafficInfo'] = trafficInfo;
          }
          isLoading = false;
        });
      } catch (e) {
        print('Error loading journey details: $e');
        setState(() {
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 48,
                    height: 48,
                    child: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF181111),
                      size: 24,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Journey Details',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF181111),
                      letterSpacing: -0.015,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // View on Map Button
                  _buildViewOnMapButton(),
                  
                  // Three Journey Cards
                  if (widget.journey != null || _foundJourney != null) ...[
                    _buildOverallJourneyCard(),
                    _buildCurrentToBusStopCard(),
                    _buildBusStopToDestinationCard(),
                  ] else ...[
                    _buildOverallJourneyCard(),
                    _buildCurrentToBusStopCard(),
                    _buildBusStopToDestinationCard(),
                  ],
                  
                  // Bus Route section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Bus Route',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF181111),
                        letterSpacing: -0.015,
                      ),
                    ),
                  ),
                  
                  // Bus stops list
                  ..._buildStopsList(),
                ],
              ),
            ),
          ),
          
          // Fare estimate button
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => _showFareDetails(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE92929),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Fare Estimate: PKR 50',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.015,
                  ),
                ),
              ),
            ),
          ),
          
          Container(height: 20, color: Colors.white),
        ],
      ),
    );
  }

  Journey? get _currentJourney => widget.journey ?? _foundJourney;

  Widget _buildViewOnMapButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () {
            if (_currentJourney != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MapScreen(
                    destinationLat: _currentJourney!.endStop.lat,
                    destinationLng: _currentJourney!.endStop.lng,
                    destinationName: _currentJourney!.endStop.name,
                  ),
                ),
              );
            }
          },
          icon: const Icon(Icons.map, color: Colors.white),
          label: Text(
            'View on Map',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE92929),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            shadowColor: const Color(0xFFE92929).withOpacity(0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildOverallJourneyCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE92929),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.route,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Overall Journey',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF181111),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildJourneyMetric(
                  icon: Icons.access_time,
                  title: 'Total Time',
                  value: '${_calculateTotalTime()} min',
                  color: const Color(0xFFE92929),
                ),
              ),
              Expanded(
                child: _buildJourneyMetric(
                  icon: Icons.straighten,
                  title: 'Total Distance',
                  value: _currentJourney != null 
                      ? '${(_calculateTotalDistance() / 1000).toStringAsFixed(1)} km'
                      : '0.0 km',
                  color: const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildJourneyMetric(
                  icon: Icons.directions_walk,
                  title: 'Walking',
                  value: _currentJourney != null 
                      ? '${((_currentJourney!.walkingDistanceToStart + _currentJourney!.walkingDistanceFromEnd) / 1000).toStringAsFixed(1)} km'
                      : '0.0 km',
                  color: const Color(0xFF2196F3),
                ),
              ),
              Expanded(
                child: _buildJourneyMetric(
                  icon: Icons.directions_bus,
                  title: 'Bus Journey',
                  value: _currentJourney != null 
                      ? '${(_calculateBusDistanceInMeters() / 1000).toStringAsFixed(1)} km'
                      : '0.0 km',
                  color: const Color(0xFFFF9800),
                ),
              ),
            ],
          ),
          if (journeyDetails != null && journeyDetails!['trafficInfo'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.trending_up,
                    color: Colors.orange.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Traffic: ${journeyDetails!['trafficInfo']['trafficLevel']}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentToBusStopCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.directions_walk,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Current Location → Bus Stop',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF181111),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildJourneyMetric(
                  icon: Icons.access_time,
                  title: 'Walking Time',
                  value: _currentJourney != null 
                      ? '${DistanceCalculator.calculateWalkingTimeMinutes(_currentJourney!.walkingDistanceToStart)} min'
                      : '0 min',
                  color: Colors.blue.shade600,
                ),
              ),
              Expanded(
                child: _buildJourneyMetric(
                  icon: Icons.straighten,
                  title: 'Distance',
                  value: _currentJourney != null 
                      ? '${(_currentJourney!.walkingDistanceToStart / 1000).toStringAsFixed(1)} km'
                      : '0.0 km',
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildJourneyMetric(
                  icon: Icons.directions_bus,
                  title: 'Bus Stop',
                  value: _currentJourney != null ? _currentJourney!.startStop.name : 'Unknown',
                  color: Colors.blue.shade600,
                ),
              ),
              Expanded(
                child: _buildJourneyMetric(
                  icon: Icons.motorcycle,
                  title: 'Bykea Time',
                  value: _currentJourney != null 
                      ? '${_calculateBykeaTime()} min'
                      : '0 min',
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Getting to ${_currentJourney?.startStop.name ?? 'Bus Stop'}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildTransportSuggestions(_currentJourney?.walkingDistanceToStart ?? 0, 'start'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusStopToDestinationCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.directions_bus,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Bus Stop → Destination',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF181111),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildJourneyMetric(
                  icon: Icons.access_time,
                  title: 'Bus Time',
                  value: '${_calculateBusTime()} min',
                  color: Colors.green.shade600,
                ),
              ),
              Expanded(
                child: _buildJourneyMetric(
                  icon: Icons.straighten,
                  title: 'Bus Distance',
                  value: '${_calculateBusDistance()} km',
                  color: Colors.green.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildJourneyMetric(
                  icon: Icons.directions_walk,
                  title: 'Final Walk',
                  value: '${_calculateFinalLegTime()} min',
                  color: Colors.green.shade600,
                ),
              ),
              Expanded(
                child: _buildJourneyMetric(
                  icon: Icons.straighten,
                  title: 'Final Distance',
                  value: '${_calculateFinalLegDistance()} km',
                  color: Colors.green.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.green.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Getting to ${widget.destinationName ?? 'Destination'}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildTransportSuggestions(_currentJourney?.walkingDistanceFromEnd ?? 0, 'end'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyMetric({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: const Color(0xFF886363),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF181111),
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ],
    );
  }

  List<Widget> _buildStopsList() {
    if (_currentJourney == null || _currentJourney!.routes.isEmpty) {
      final stops = [
        'Stop 1', 'Stop 2', 'Stop 3', 'Stop 4', 'Stop 5',
        'Stop 6', 'Stop 7', 'Stop 8', 'Stop 9', 'Stop 10'
      ];
      return stops.map((stop) => _buildStopItem(stop)).toList();
    }
    
    final List<Widget> stopWidgets = [];
    
    // Add start stop
    stopWidgets.add(_buildStopItem(_currentJourney!.startStop.name, isStart: true));
    
    // Add route stops
    for (final route in _currentJourney!.routes) {
      for (final stop in route.stops) {
        if (stop.id != _currentJourney!.startStop.id && stop.id != _currentJourney!.endStop.id) {
          stopWidgets.add(_buildStopItem(stop.name));
        }
      }
    }
    
    // Add transfer stop if exists
    if (_currentJourney!.transferStop != null) {
      stopWidgets.add(_buildStopItem(_currentJourney!.transferStop!.name, isTransfer: true));
    }
    
    // Add end stop
    stopWidgets.add(_buildStopItem(_currentJourney!.endStop.name, isEnd: true));
    
    return stopWidgets;
  }

  Widget _buildStopItem(String stopName, {bool isStart = false, bool isEnd = false, bool isTransfer = false}) {
    IconData icon;
    Color iconColor;
    
    if (isStart) {
      icon = Icons.trip_origin;
      iconColor = Colors.green;
    } else if (isEnd) {
      icon = Icons.place;
      iconColor = Colors.red;
    } else if (isTransfer) {
      icon = Icons.swap_horiz;
      iconColor = Colors.orange;
    } else {
      icon = Icons.directions_bus;
      iconColor = const Color(0xFF181111);
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              stopName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: const Color(0xFF181111),
                fontWeight: (isStart || isEnd || isTransfer) ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  int _calculateBusTime() {
    if (_currentJourney == null) return 0;
    
    final busDistance = _currentJourney!.totalDistance - _currentJourney!.walkingDistanceToStart - _currentJourney!.walkingDistanceFromEnd;
    
    return DistanceCalculator.calculatePublicTransportTimeMinutes(
      distanceInMeters: busDistance,
      isBRT: true,
      requiresTransfer: _currentJourney!.requiresTransfer,
      departureTime: DateTime.now(),
    );
  }

  String _calculateBusDistance() {
    if (_currentJourney == null) return '0';
    
    final busDistance = _currentJourney!.totalDistance - _currentJourney!.walkingDistanceToStart - _currentJourney!.walkingDistanceFromEnd;
    return (busDistance / 1000).toStringAsFixed(1);
  }

  double _calculateBusDistanceInMeters() {
    if (_currentJourney == null) return 0;
    
    final busDistance = _currentJourney!.totalDistance - _currentJourney!.walkingDistanceToStart - _currentJourney!.walkingDistanceFromEnd;
    return busDistance;
  }

  int _calculateTotalTime() {
    if (_currentJourney == null) return 0;
    
    final busDistance = _currentJourney!.totalDistance - _currentJourney!.walkingDistanceToStart - _currentJourney!.walkingDistanceFromEnd;
    
    return DistanceCalculator.calculateJourneyTimeWithBykea(
      distanceToBusStop: _currentJourney!.walkingDistanceToStart,
      busJourneyDistance: busDistance,
      distanceFromBusStopToDestination: _currentJourney!.walkingDistanceFromEnd,
      requiresTransfer: _currentJourney!.requiresTransfer,
      departureTime: DateTime.now(),
    );
  }

  double _calculateTotalDistance() {
    if (_currentJourney == null) return 0;
    
    final busDistance = _currentJourney!.totalDistance - _currentJourney!.walkingDistanceToStart - _currentJourney!.walkingDistanceFromEnd;
    return _currentJourney!.walkingDistanceToStart + busDistance + _currentJourney!.walkingDistanceFromEnd;
  }

  int _calculateBykeaTime() {
    if (_currentJourney == null) return 0;
    
    return DistanceCalculator.calculateDrivingTimeMinutes(
      distanceInMeters: _currentJourney!.walkingDistanceToStart,
      vehicleType: 'bykea',
      departureTime: DateTime.now(),
    );
  }

  int _calculateFinalLegTime() {
    if (_currentJourney == null) return 0;
    
    final distance = _currentJourney!.walkingDistanceFromEnd;
    
    if (distance < 500) {
      // Short distance: walking
      return DistanceCalculator.calculateWalkingTimeMinutes(distance);
    } else if (distance < 2000) {
      // Medium distance: rickshaw
      return DistanceCalculator.calculateDrivingTimeMinutes(
        distanceInMeters: distance,
        vehicleType: 'rickshaw',
        departureTime: DateTime.now(),
      );
    } else {
      // Long distance: Bykea
      return DistanceCalculator.calculateDrivingTimeMinutes(
        distanceInMeters: distance,
        vehicleType: 'bykea',
        departureTime: DateTime.now(),
      );
    }
  }

  String _calculateFinalLegDistance() {
    if (_currentJourney == null) return '0';
    return (_currentJourney!.walkingDistanceFromEnd / 1000).toStringAsFixed(1);
  }

  String _getFinalLegDescription() {
    if (_currentJourney == null) return 'walk to destination';
    
    final distance = _currentJourney!.walkingDistanceFromEnd;
    
    if (distance < 500) {
      return 'walk ${(distance / 1000).toStringAsFixed(1)}km to destination';
    } else if (distance < 2000) {
      return 'take rickshaw for ${_calculateFinalLegTime()} min';
    } else {
      return 'take Bykea for ${_calculateFinalLegTime()} min';
    }
  }

  Widget _buildTransportSuggestions(double distance, String type) {
    final List<Widget> suggestions = [];
    
    // Walking suggestion (always available)
    final walkingTime = DistanceCalculator.calculateWalkingTimeMinutes(distance);
    suggestions.add(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_walk, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              'Walk ${(distance / 1000).toStringAsFixed(1)}km (${walkingTime}min)',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
    
    // Rickshaw suggestion (for medium distances)
    if (distance >= 500 && distance < 2000) {
      final rickshawTime = DistanceCalculator.calculateDrivingTimeMinutes(
        distanceInMeters: distance,
        vehicleType: 'rickshaw',
        departureTime: DateTime.now(),
      );
      suggestions.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.motorcycle, size: 14, color: Colors.orange.shade600),
              const SizedBox(width: 4),
              Text(
                'Rickshaw (${rickshawTime}min)',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Bykea suggestion (for longer distances)
    if (distance >= 1000) {
      final bykeaTime = DistanceCalculator.calculateDrivingTimeMinutes(
        distanceInMeters: distance,
        vehicleType: 'bykea',
        departureTime: DateTime.now(),
      );
      suggestions.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.motorcycle, size: 14, color: Colors.blue.shade600),
              const SizedBox(width: 4),
              Text(
                'Bykea (${bykeaTime}min)',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: suggestions,
    );
  }

  void _showFareDetails() {
    if (_currentJourney == null) return;
    _showFareDialog();
  }

  void _showFareDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fare Estimate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BRT Fare: PKR 50'),
            Text('Bykea (if needed): PKR 30-50'),
            Text('Rickshaw (if needed): PKR 40-60'),
            const SizedBox(height: 8),
            const Text('Total Estimated: PKR 50-110', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}