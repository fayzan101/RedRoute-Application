import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/route.dart';
import '../services/data_service.dart';
import 'package:provider/provider.dart';

class BusRouteDetailsScreen extends StatelessWidget {
  final String routeName;
  
  const BusRouteDetailsScreen({
    super.key,
    required this.routeName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
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
                    child: Icon(
                      Icons.arrow_back,
                      color: isDark ? Colors.white : const Color(0xFF181111),
                      size: 24,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Bus Route Details',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF181111),
                      letterSpacing: -0.015,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          
          // Route Info Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey.shade600 : Colors.grey[300]!,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark 
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Consumer<DataService>(
              builder: (context, dataService, child) {
                final route = dataService.getRouteByName(routeName);
                
                if (route == null) {
                  return const Center(
                    child: Text('Route not found'),
                  );
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE92929),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            routeName.split(' ').last,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                routeName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF181111),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${route.stops.length} stops',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRouteMetric(
                            context,
                            icon: Icons.access_time,
                            title: 'Estimated Time',
                            value: '${_calculateRouteTime(route)} min',
                            color: const Color(0xFFE92929),
                          ),
                        ),
                        Expanded(
                          child: _buildRouteMetric(
                            context,
                            icon: Icons.straighten,
                            title: 'Total Distance',
                            value: '${_calculateRouteDistance(route).toStringAsFixed(1)} km',
                            color: const Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRouteMetric(
                            context,
                            icon: Icons.attach_money,
                            title: 'Fare',
                            value: 'PKR 50',
                            color: const Color(0xFFFF9800),
                          ),
                        ),
                        Expanded(
                          child: _buildRouteMetric(
                            context,
                            icon: Icons.schedule,
                            title: 'Frequency',
                            value: 'Every 5-10 min',
                            color: const Color(0xFF2196F3),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Stops List Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.directions_bus,
                  color: isDark ? Colors.white : const Color(0xFF181111),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Route Stops',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF181111),
                  ),
                ),
              ],
            ),
          ),
          
          // Stops List
          Expanded(
            child: Consumer<DataService>(
              builder: (context, dataService, child) {
                final route = dataService.getRouteByName(routeName);
                
                if (route == null) {
                  return const Center(
                    child: Text('Route not found'),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: route.stops.length,
                  itemBuilder: (context, index) {
                    final stop = route.stops[index];
                    final isFirst = index == 0;
                    final isLast = index == route.stops.length - 1;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          // Stop indicator
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isFirst 
                                  ? Colors.green 
                                  : isLast 
                                      ? Colors.red 
                                      : const Color(0xFFE92929),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isFirst 
                                  ? Icons.trip_origin 
                                  : isLast 
                                      ? Icons.place 
                                      : Icons.directions_bus,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          
                          // Connecting line (except for last item)
                          if (!isLast)
                            Container(
                              width: 2,
                              height: 40,
                              margin: const EdgeInsets.symmetric(horizontal: 11),
                              color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                            ),
                          
                          const SizedBox(width: 16),
                          
                          // Stop details
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey.shade800 : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade200,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark 
                                        ? Colors.black.withOpacity(0.2)
                                        : Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stop.name,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF181111),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Stop ${index + 1} of ${route.stops.length}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                  ),
                                  if (isFirst) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Starting Point',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                  ] else if (isLast) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Terminal',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteMetric(BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: isDark ? Colors.grey.shade400 : const Color(0xFF886363),
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
            color: isDark ? Colors.white : const Color(0xFF181111),
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  int _calculateRouteTime(BusRoute route) {
    // Estimate time based on number of stops and average time per stop
    return route.stops.length * 3; // 3 minutes per stop average
  }

  double _calculateRouteDistance(BusRoute route) {
    // Calculate total distance between all stops
    double totalDistance = 0;
    for (int i = 0; i < route.stops.length - 1; i++) {
      final stop1 = route.stops[i];
      final stop2 = route.stops[i + 1];
      
      // Calculate distance between two points using Haversine formula
      final lat1 = stop1.lat;
      final lon1 = stop1.lng;
      final lat2 = stop2.lat;
      final lon2 = stop2.lng;
      
      const double earthRadius = 6371000; // Earth's radius in meters
      final dLat = (lat2 - lat1) * (pi / 180);
      final dLon = (lon2 - lon1) * (pi / 180);
      final a = sin(dLat / 2) * sin(dLat / 2) +
          cos(lat1 * (pi / 180)) * cos(lat2 * (pi / 180)) *
          sin(dLon / 2) * sin(dLon / 2);
      final c = 2 * atan2(sqrt(a), sqrt(1 - a));
      final distance = earthRadius * c;
      
      totalDistance += distance;
    }
    
    return totalDistance / 1000; // Convert to kilometers
  }
} 