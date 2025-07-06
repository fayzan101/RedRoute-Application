import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/route.dart';
import '../utils/distance_calculator.dart';

class RouteDetailsScreen extends StatelessWidget {
  final Journey? journey;
  
  const RouteDetailsScreen({super.key, this.journey});

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
                    'People\'s Bus Service',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF181111),
                      letterSpacing: -0.015,
                    ),
                  ),
                ),
                const SizedBox(width: 48), // Balance the layout
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // From your location section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'From your location',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF181111),
                        letterSpacing: -0.015,
                      ),
                    ),
                  ),
                  
                  // Transport options
                  if (journey != null) ...[
                    _buildTransportOption(
                      icon: Icons.directions_walk,
                      title: 'Walk to ${journey!.startStop.name}',
                      subtitle: '${(journey!.walkingDistanceToStart * 1000).round()}m walk',
                    ),
                    _buildTransportOption(
                      icon: Icons.directions_bus,
                      title: 'BRT Journey',
                      subtitle: '${_calculateBusTime()} min • ${_calculateBusDistance()}km',
                    ),
                    _buildTransportOption(
                      icon: Icons.motorcycle,
                      title: 'Bykea to Bus Stop',
                      subtitle: '${_calculateBykeaTime()} min • ${_calculateBykeaDistance()}km',
                    ),
                    _buildTransportOption(
                      icon: _getFinalLegIcon(),
                      title: 'Final Leg to Destination',
                      subtitle: '${_calculateFinalLegTime()} min • ${_calculateFinalLegDistance()}km',
                    ),
                    _buildTransportOption(
                      icon: Icons.access_time,
                      title: 'Total Journey Time',
                      subtitle: '${_calculateTotalTime()} min (Complete Journey)',
                    ),
                    _buildTransportOption(
                      icon: Icons.motorcycle,
                      title: 'Bykea to ${journey!.startStop.name}',
                      subtitle: '${(journey!.walkingDistanceToStart * 1000 / 500).round()} min Bykea',
                    ),
                    _buildTransportOption(
                      icon: Icons.directions_car,
                      title: 'Rickshaw to ${journey!.startStop.name}',
                      subtitle: '${(journey!.walkingDistanceToStart * 1000 / 300).round()} min Rickshaw',
                    ),
                  ] else ...[
                    _buildTransportOption(
                      icon: Icons.directions_walk,
                      title: 'Walk to Stop 1',
                      subtitle: '10 min walk',
                    ),
                    _buildTransportOption(
                      icon: Icons.motorcycle,
                      title: 'Bykea to Stop 1',
                      subtitle: '15 min Bykea',
                    ),
                    _buildTransportOption(
                      icon: Icons.directions_car,
                      title: 'Rickshaw to Stop 1',
                      subtitle: '20 min Rickshaw',
                    ),
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
                  
                  // Route map
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: const DecorationImage(
                        image: NetworkImage(
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuCSjyp0vpv_vOvUNUjhfGPMXmwtxe4JsVHPxVI9CvMthpOxCZynmMBsO-xuocOTIak83Q7fhc7r6pefobcyE_CGjbKpHj7ozVRml7h32KVvLUuZm-f4Tl4qnShFn7Jbpg5vAzYW5_vwmJEDaE9OVoM6nM3QVklU5K7K2sUafRQaKYdWNZ7PomHujkcAH0dq2qfTxN_nmW0aFx9hLCmw39q7W7vEbJYHCuInh5eNtELedopuvcMqD96WlCpdeihNx_OpXADUTdKhuOFW'
                        ),
                        fit: BoxFit.cover,
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
                onPressed: () {},
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
          
          Container(height: 20, color: Colors.white), // Bottom safe area
        ],
      ),
    );
  }

  Widget _buildTransportOption({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F0F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF181111),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF181111),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFF886363),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStopsList() {
    if (journey == null || journey!.routes.isEmpty) {
      final stops = [
        'Stop 1', 'Stop 2', 'Stop 3', 'Stop 4', 'Stop 5',
        'Stop 6', 'Stop 7', 'Stop 8', 'Stop 9', 'Stop 10'
      ];
      return stops.map((stop) => _buildStopItem(stop)).toList();
    }
    
    final List<Widget> stopWidgets = [];
    
    // Add start stop
    stopWidgets.add(_buildStopItem(journey!.startStop.name, isStart: true));
    
    // Add route stops
    for (final route in journey!.routes) {
      for (final stop in route.stops) {
        if (stop.id != journey!.startStop.id && stop.id != journey!.endStop.id) {
          stopWidgets.add(_buildStopItem(stop.name));
        }
      }
    }
    
    // Add transfer stop if exists
    if (journey!.transferStop != null) {
      stopWidgets.add(_buildStopItem(journey!.transferStop!.name, isTransfer: true));
    }
    
    // Add end stop
    stopWidgets.add(_buildStopItem(journey!.endStop.name, isEnd: true));
    
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
    if (journey == null) return 0;
    
    final busDistance = journey!.totalDistance - journey!.walkingDistanceToStart - journey!.walkingDistanceFromEnd;
    
    return DistanceCalculator.calculatePublicTransportTimeMinutes(
      distanceInMeters: busDistance,
      isBRT: true,
      requiresTransfer: journey!.requiresTransfer,
      departureTime: DateTime.now(),
    );
  }

  String _calculateBusDistance() {
    if (journey == null) return '0';
    
    final busDistance = journey!.totalDistance - journey!.walkingDistanceToStart - journey!.walkingDistanceFromEnd;
    return (busDistance / 1000).toStringAsFixed(1);
  }

  int _calculateTotalTime() {
    if (journey == null) return 0;
    
    final busDistance = journey!.totalDistance - journey!.walkingDistanceToStart - journey!.walkingDistanceFromEnd;
    
    return DistanceCalculator.calculateJourneyTimeWithBykea(
      distanceToBusStop: journey!.walkingDistanceToStart,
      busJourneyDistance: busDistance,
      distanceFromBusStopToDestination: journey!.walkingDistanceFromEnd,
      requiresTransfer: journey!.requiresTransfer,
      departureTime: DateTime.now(),
    );
  }

  int _calculateBykeaTime() {
    if (journey == null) return 0;
    
    return DistanceCalculator.calculateDrivingTimeMinutes(
      distanceInMeters: journey!.walkingDistanceToStart,
      vehicleType: 'bykea',
      departureTime: DateTime.now(),
    );
  }

  String _calculateBykeaDistance() {
    if (journey == null) return '0';
    return (journey!.walkingDistanceToStart / 1000).toStringAsFixed(1);
  }

  int _calculateFinalLegTime() {
    if (journey == null) return 0;
    
    final distance = journey!.walkingDistanceFromEnd;
    
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
    if (journey == null) return '0';
    return (journey!.walkingDistanceFromEnd / 1000).toStringAsFixed(1);
  }

  IconData _getFinalLegIcon() {
    if (journey == null) return Icons.directions_walk;
    
    final distance = journey!.walkingDistanceFromEnd;
    
    if (distance < 500) {
      return Icons.directions_walk;
    } else if (distance < 2000) {
      return Icons.directions_car;
    } else {
      return Icons.motorcycle;
    }
  }
} 