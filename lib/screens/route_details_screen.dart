import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/route.dart';
import '../utils/distance_calculator.dart';
import '../services/mapbox_service.dart';
import '../services/enhanced_location_service.dart';
import '../services/route_finder.dart';
import '../services/transport_preference_service.dart';
import '../screens/map_screen.dart';
import '../screens/bus_route_details_screen.dart';
import 'package:flutter/foundation.dart';

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

  @override
  @override
void didChangeDependencies() {
  super.didChangeDependencies();

  final isDark = Theme.of(context).brightness == Brightness.dark;

  // Configure system UI overlays
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: isDark ? const Color(0xFF121212) : Colors.white,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark, // Android
      // ⚠️ REMOVE statusBarBrightness (iOS) if causing conflict
      systemNavigationBarColor: isDark ? Colors.black : Colors.white,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ),
  );
}

  @override
  void dispose() {
    // Reset system UI to default when leaving the screen
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
    super.dispose();
  }

  Future<void> _findRoute() async {
    // Safely access providers with error handling
    EnhancedLocationService? locationService;
    RouteFinder? routeFinder;
    
    try {
      locationService = context.read<EnhancedLocationService>();
      routeFinder = context.read<RouteFinder>();
    } catch (e) {
      print('Provider not found: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service not available. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
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
      // Add timeout to prevent infinite loading (increased for first-time initialization)
      final journey = await routeFinder.findBestRoute(
        userLat: userPosition.latitude,
        userLng: userPosition.longitude,
        destLat: widget.destinationLat!,
        destLng: widget.destinationLng!,
      ).timeout(
        const Duration(seconds: 45), // Increased timeout for first-time initialization
        onTimeout: () {
          throw TimeoutException('Route finding timed out. This might be due to first-time initialization. Please try again.');
        },
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
    } on TimeoutException catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${e.message}'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _findRoute(),
            textColor: Colors.white,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      
      String errorMessage = 'Error finding route';
      if (e.toString().contains('timeout') || e.toString().contains('Timeout')) {
        errorMessage = 'Route finding is taking longer than expected. This might be due to first-time initialization.';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'Network connection issue. Please check your internet connection.';
      } else {
        errorMessage = 'Error finding route: ${e.toString().split(':').last.trim()}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _findRoute(),
            textColor: Colors.white,
          ),
        ),
      );
    }
  }

  Future<void> _loadJourneyDetails([Journey? journey]) async {
    final currentJourney = journey ?? widget.journey;
    if (currentJourney != null) {
      try {
        // Get user's current location
        final locationService = context.read<EnhancedLocationService>();
        final userPosition = locationService.currentPosition;
        
        if (userPosition != null) {
          // Get accurate route information using Mapbox Directions API
          final Map<String, dynamic> routeDetails = {};
          
          
          
          // Check for very short distances
          final userToStopDistance = DistanceCalculator.calculateDistance(
            userPosition.latitude, userPosition.longitude,
            currentJourney.startStop.lat, currentJourney.startStop.lng
          );
         
      
          
          final drivingToBusStop = await _getDrivingRouteToBusStop(
            startLat: userPosition.latitude,
            startLng: userPosition.longitude,
            endLat: currentJourney.startStop.lat,
            endLng: currentJourney.startStop.lng,
          );
          routeDetails['drivingToBusStop'] = drivingToBusStop;
          
         
          
          // Get driving route for bus journey (simulated)
          final busJourney = await _getDrivingRouteInfo(
            startLat: currentJourney.startStop.lat,
            startLng: currentJourney.startStop.lng,
            endLat: currentJourney.endStop.lat,
            endLng: currentJourney.endStop.lng,
          );
          routeDetails['busJourney'] = busJourney;
          
          // Get walking route from bus stop to destination
        
          
          // Check for very short distances
          final stopToDestDistance = DistanceCalculator.calculateDistance(
            currentJourney.endStop.lat, currentJourney.endStop.lng,
            widget.destinationLat ?? currentJourney.endStop.lat,
            widget.destinationLng ?? currentJourney.endStop.lng
          );
         
          
          final walkingToDestination = await _getWalkingRouteInfo(
            startLat: currentJourney.endStop.lat,
            startLng: currentJourney.endStop.lng,
            endLat: widget.destinationLat ?? currentJourney.endStop.lat,
            endLng: widget.destinationLng ?? currentJourney.endStop.lng,
          );
          routeDetails['walkingToDestination'] = walkingToDestination;
     
          
          // Calculate total journey info with validation
          final totalDistance = drivingToBusStop['distance'] + 
                              busJourney['distance'] + 
                              walkingToDestination['distance'];
          final totalDuration = drivingToBusStop['duration'] + 
                               busJourney['duration'] + 
                               walkingToDestination['duration'];
          
          routeDetails['totalDistance'] = totalDistance;
          routeDetails['totalDuration'] = totalDuration;
          routeDetails['totalDistanceKm'] = totalDistance / 1000;
          routeDetails['totalDurationMinutes'] = (totalDuration / 60).round();
          
          // Get legacy journey details for compatibility
          final details = await MapboxService.getJourneyDetails(
            startLat: userPosition.latitude,
            startLng: userPosition.longitude,
            endLat: widget.destinationLat ?? currentJourney.endStop.lat,
            endLng: widget.destinationLng ?? currentJourney.endStop.lng,
            busStopLat: currentJourney.startStop.lat,
            busStopLng: currentJourney.startStop.lng,
            destinationStopLat: currentJourney.endStop.lat,
            destinationStopLng: currentJourney.endStop.lng,
          );

          setState(() {
            journeyDetails = {...details, ...routeDetails};
            isLoading = false;
          });
        } else {
          // Fallback to legacy method if location not available
          final details = await MapboxService.getJourneyDetails(
            startLat: currentJourney.startStop.lat,
            startLng: currentJourney.startStop.lng,
            endLat: widget.destinationLat ?? currentJourney.endStop.lat,
            endLng: widget.destinationLng ?? currentJourney.endStop.lng,
            busStopLat: currentJourney.startStop.lat,
            busStopLng: currentJourney.startStop.lng,
            destinationStopLat: currentJourney.endStop.lat,
            destinationStopLng: currentJourney.endStop.lng,
          );

          setState(() {
            journeyDetails = details;
            isLoading = false;
          });
        }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Ensure providers are available
    try {
      context.read<EnhancedLocationService>();
      context.read<RouteFinder>();
    } catch (e) {
      // If providers are not available, show error screen
      return Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: isDark ? Colors.white : Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Service Unavailable',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again or restart the app',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Journey Details'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
        children: [
          
          // Loading indicator or content
          Expanded(
            child: isLoading 
                ? _buildLoadingIndicator()
                : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                        // View on Map Button
                        _buildViewOnMapButton(),
                        
                        // Journey Cards
                        if (widget.journey != null || _foundJourney != null) ...[
                          _buildOverallJourneyCard(),
                          _buildCurrentToBusStopCard(),
                          _buildBusJourneyCard(),
                          _buildBusStopToDestinationCard(),
                        ] else ...[
                          _buildOverallJourneyCard(),
                          _buildCurrentToBusStopCard(),
                          _buildBusJourneyCard(),
                          _buildBusStopToDestinationCard(),
                        ],
                        
                        // Action Buttons
                        if (widget.journey != null || _foundJourney != null) ...[
                          const SizedBox(height: 16),
                          _buildActionButtons(),
                        ],
                      ],
                      ),
                    ),
                  ),
                  

          
          Container(height: 20, color: isDark ? Colors.grey.shade900 : Colors.white),
        ],
      ), // Close Column
    ), // Close SafeArea
  ); // Close Scaffold
  }

  Journey? get _currentJourney => widget.journey ?? _foundJourney;

  Widget _buildLoadingIndicator() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated loading indicator
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE92929).withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE92929)),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Loading text
          Text(
            'Finding Best Route...',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF181111),
            ),
          ),
          const SizedBox(height: 8),
          
          // Subtitle
          Text(
            'Analyzing BRT routes and calculating journey time',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Progress steps
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                _buildLoadingStep(
                  icon: Icons.location_on,
                  title: 'Getting your location',
                  isCompleted: true,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildLoadingStep(
                  icon: Icons.search,
                  title: 'Finding nearest BRT stops',
                  isCompleted: isLoading && _foundJourney != null,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildLoadingStep(
                  icon: Icons.route,
                  title: 'Calculating optimal route',
                  isCompleted: !isLoading && _foundJourney != null,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Retry button (appears after 10 seconds)
          FutureBuilder(
            future: Future.delayed(const Duration(seconds: 10)),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return ElevatedButton.icon(
                  onPressed: () => _findRoute(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE92929),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingStep({
    required IconData icon,
    required String title,
    required bool isCompleted,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted 
                ? const Color(0xFFE92929) 
                : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            color: isCompleted 
                ? Colors.white 
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
              color: isCompleted 
                  ? (isDark ? Colors.white : const Color(0xFF181111))
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
          ),
        ),
      ],
    );
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  color: isDark ? Colors.white : const Color(0xFF181111),
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
                    icon: Icons.swap_horiz,
                    title: 'Transfers',
                  value: _currentJourney != null 
                      ? _currentJourney!.requiresTransfer ? '1' : '0'
                      : '0',
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
                color: isDark ? Colors.orange.shade900 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.orange.shade700 : Colors.orange.shade200,
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.blue.shade600 : Colors.blue.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.blue.withOpacity(0.3)
                : Colors.blue.withOpacity(0.05),
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
                  color: isDark ? Colors.white : const Color(0xFF181111),
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
                  title: 'Driving Time',
                  value: _currentJourney != null 
                      ? '${_getDrivingTimeToBusStop()} min'
                      : '0 min',
                  color: Colors.blue.shade600,
                ),
              ),
              Expanded(
                child: _buildJourneyMetric(
                  icon: Icons.straighten,
                  title: 'Driving Distance',
                  value: _currentJourney != null 
                      ? '${_getDrivingDistanceToBusStop()} km'
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
            ],
          ),
          const SizedBox(height: 12),
                      Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.shade800 : Colors.blue.shade100,
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
                _buildTransportSuggestions(_getDrivingDistanceToBusStopValue(), 'start'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusStopToDestinationCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.green.shade900 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.green.shade600 : Colors.green.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.green.withOpacity(0.3)
                : Colors.green.withOpacity(0.05),
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
                  color: isDark ? Colors.white : const Color(0xFF181111),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildJourneyMetric(
                  icon: Icons.straighten,
                  title: 'Distance',
                  value: '${_calculateFinalLegDistance()} km',
                  color: Colors.green.shade600,
                ),
              ),
              Expanded(
                child: _buildJourneyMetric(
                  icon: Icons.access_time,
                  title: 'Time',
                  value: '${_calculateFinalLegTime()} min',
                  color: Colors.green.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
                      Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.green.shade800 : Colors.green.shade100,
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

  Widget _buildBusJourneyCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.blue.shade600 : Colors.blue.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.blue.withOpacity(0.3)
                : Colors.blue.withOpacity(0.05),
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
                  Icons.directions_bus,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Bus Journey Details',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF181111),
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
                  title: 'Driving Time',
                  value: '${_getDrivingTimeForBusJourney()} min',
                  color: Colors.blue.shade600,
                ),
              ),
              Expanded(
                child: _buildJourneyMetric(
                  icon: Icons.straighten,
                  title: 'Driving Distance',
                  value: '${_getDrivingDistanceForBusJourney()} km',
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
                  icon: Icons.route,
                  title: 'Routes',
                  value: _getRouteNames(),
                  color: Colors.blue.shade600,
                ),
              ),
              Expanded(
                child: _buildJourneyMetric(
                  icon: Icons.swap_horiz,
                  title: 'Transfers',
                  value: _currentJourney?.requiresTransfer == true ? '1' : '0',
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.blue.shade800 : Colors.blue.shade100,
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
                        'From ${_currentJourney?.startStop.name ?? 'Boarding Stop'} to ${_currentJourney?.endStop.name ?? 'Destination Stop'}',
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
                _buildBusJourneyDetails(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusJourneyDetails() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_currentJourney == null) {
      return Text(
        'No journey details available',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      );
    }

    final List<Widget> details = [];
    
    // Show boarding stop
    details.add(
      Row(
        children: [
          Icon(Icons.trip_origin, size: 14, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Board at: ${_currentJourney!.startStop.name}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: isDark ? Colors.white : const Color(0xFF181111),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
    
    details.add(const SizedBox(height: 8));
    
    // Show routes
    if (_currentJourney!.routes.isNotEmpty) {
      final routeNames = _currentJourney!.routes.map((r) => r.name).join(', ');
      details.add(
        Row(
          children: [
            Icon(Icons.directions_bus, size: 14, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Routes: $routeNames',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: isDark ? Colors.white : const Color(0xFF181111),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
      details.add(const SizedBox(height: 8));
    }
    
    // Show transfer if needed
    if (_currentJourney!.requiresTransfer && _currentJourney!.transferStop != null) {
      details.add(
        Row(
          children: [
            Icon(Icons.swap_horiz, size: 14, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Transfer at: ${_currentJourney!.transferStop!.name}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: isDark ? Colors.white : const Color(0xFF181111),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
      details.add(const SizedBox(height: 8));
    }
    
    // Show destination stop
    details.add(
      Row(
        children: [
          Icon(Icons.place, size: 14, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Get off at: ${_currentJourney!.endStop.name}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: isDark ? Colors.white : const Color(0xFF181111),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
    
    return Column(children: details);
  }

  String _getRouteNames() {
    if (_currentJourney == null || _currentJourney!.routes.isEmpty) {
      return 'N/A';
    }
    
    final routeNames = _currentJourney!.routes.map((r) => r.name).toList();
    if (routeNames.length <= 2) {
      return routeNames.join(', ');
    } else {
      return '${routeNames.take(2).join(', ')} +${routeNames.length - 2}';
    }
  }

  Widget _buildJourneyMetric({
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
      iconColor = isDark ? Colors.white : const Color(0xFF181111);
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
                color: isDark ? Colors.white : const Color(0xFF181111),
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
    
    // Use the pre-calculated bus time from the Journey model
    return _currentJourney!.busTime;
  }

  String _calculateBusDistance() {
    if (_currentJourney == null) return '0';
    
    return (_currentJourney!.busDistance / 1000).toStringAsFixed(1);
  }

  double _calculateBusDistanceInMeters() {
    if (_currentJourney == null) return 0;
    
    return _currentJourney!.busDistance;
  }

  int _calculateTotalTime() {
    if (_currentJourney == null) return 0;
    
    // Sum of driving times from the 2nd, 3rd, and 4th cards
    final drivingTimeToBusStop = _getDrivingTimeToBusStop(); // 2nd card
    final drivingTimeForBusJourney = _getDrivingTimeForBusJourney(); // 3rd card
    final finalLegTime = _calculateFinalLegTime(); // 4th card
    
    return drivingTimeToBusStop + drivingTimeForBusJourney + finalLegTime;
  }

  double _calculateTotalDistance() {
    if (_currentJourney == null) return 0;
    
    // Calculate driving distances for each segment
    final drivingDistanceToBusStop = _getDrivingDistanceToBusStopValue(); // Use actual driving distance
    final drivingDistanceBetweenStops = _getDrivingDistanceForBusJourneyValue(); // Use actual driving distance
    final walkingDistanceFromBusStop = _currentJourney!.walkingDistanceFromEnd;
    
    return drivingDistanceToBusStop + drivingDistanceBetweenStops + walkingDistanceFromBusStop;
  }

  int _calculateBykeaTime() {
    if (_currentJourney == null) return 0;
    
    // Use the pre-calculated total time from the Journey model
    return _currentJourney!.totalTime;
  }

  int _calculateFinalLegTime() {
    if (_currentJourney == null) return 0;
    
    // Use the pre-calculated time from the Journey model
    return _currentJourney!.walkingTimeFromEnd;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Widget> suggestions = [];
    
    // For the 2nd card (start), show simplified Bykea suggestion
    if (type == 'start') {
      final drivingTime = _getDrivingTimeToBusStop();
      final drivingDistance = _getDrivingDistanceToBusStopValue();
      final fare = DistanceCalculator.calculateBykeaFare(drivingDistance);
      suggestions.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.motorcycle, size: 14, color: Colors.blue.shade700),
              const SizedBox(width: 4),
              Text(
                'Bykea: ${drivingTime} mins • Rs. $fare',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
      return Wrap(spacing: 8, runSpacing: 4, children: suggestions);
    }
    
    // For the 4th card (end), show transport suggestions based on new distance criteria
    if (type == 'end') {
      final distanceInKm = distance / 1000.0;
      final time = _calculateFinalLegTime();
      
      if (distanceInKm < 1.0) {
        // Walking for less than 1km
        suggestions.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_walk, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Walk (${time}min)',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (distanceInKm >= 2.0 && distanceInKm < 4.0) {
        // Rickshaw for 2-4km
        final fare = DistanceCalculator.calculateRickshawFare(distance);
        suggestions.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.motorcycle, size: 14, color: Colors.orange.shade600),
                const SizedBox(width: 4),
                Text(
                  'Rickshaw (${time}min • Rs. $fare)',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (distanceInKm >= 5.0) {
        // Bykea for 5km or more
        final fare = DistanceCalculator.calculateBykeaFare(distance);
        suggestions.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.motorcycle, size: 14, color: Colors.blue.shade600),
                const SizedBox(width: 4),
                Text(
                  'Bykea (${time}min • Rs. $fare)',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return Wrap(spacing: 6, runSpacing: 6, children: suggestions);
    }
    
    // For other cards, show the original transport suggestions
    // Walking suggestion (always available)
    final walkingTime = _currentJourney != null ? _currentJourney!.walkingTimeToStart : DistanceCalculator.calculateWalkingTimeMinutes(distance);
    suggestions.add(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_walk, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              'Walk ${(distance / 1000).toStringAsFixed(1)}km (${walkingTime}min)',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
    
        // Rickshaw suggestion (for medium distances)
    if (distance >= 500 && distance < 2000) {
      final rickshawTime = _currentJourney != null ? _currentJourney!.walkingTimeToStart : DistanceCalculator.calculateRickshawTimeMinutes(distance);
      suggestions.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
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
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
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
      final bykeaTime = _currentJourney != null ? _currentJourney!.totalTime : DistanceCalculator.calculateJourneyTimeWithBykea(distance);
      suggestions.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade800 : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
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
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
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

  /// Get route information using Mapbox Directions API with fallback to local calculation
  Future<Map<String, dynamic>> _getMapboxRouteInfo({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    MapboxRouteType routeType = MapboxRouteType.drivingTraffic,
  }) async {
    // Validate coordinates and distance
    final validation = _validateRouteRequest(startLat, startLng, endLat, endLng, routeType);
    if (!validation['isValid']) {
      
      return validation['fallbackResult'];
    }
    
    // Calculate straight-line distance for comparison
    final straightLineDistance = DistanceCalculator.calculateDistance(startLat, startLng, endLat, endLng);

    
    try {
      final routeInfo = await MapboxService.getRouteInfo(
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
        routeType: routeType,
      );
      
      if (routeInfo != null) {
        final mapboxDistance = routeInfo.distance;
        final ratio = mapboxDistance / straightLineDistance;
        

        
        // Validate the distance is reasonable
        if (ratio >= 0.5 && ratio <= 3.0) {
        
          return {
            'distance': routeInfo.distance,
            'duration': routeInfo.duration,
            'formattedDistance': routeInfo.formattedDistance,
            'formattedDuration': routeInfo.formattedDuration,
            'durationMinutes': routeInfo.durationMinutes,
            'distanceKm': routeInfo.distanceKm,
            'source': 'mapbox',
          };
        } else {
          
          print('📍 RouteDetails: Falling back to local calculation with road network adjustment');
        }
      }
    } catch (e) {
      print('❌ RouteDetailsScreen: Mapbox route calculation failed: $e');
    }
    
    // Fallback to local calculation with road network adjustment

    final localDistance = DistanceCalculator.calculateDistance(startLat, startLng, endLat, endLng);
    
    // Apply road network adjustment factor
    double adjustedDistance;
    int localDuration;
    
    switch (routeType) {
      case MapboxRouteType.walking:
        adjustedDistance = localDistance * 1.3; // Walking routes are more direct
        localDuration = DistanceCalculator.calculateWalkingTimeMinutes(adjustedDistance);
        break;
      case MapboxRouteType.cycling:
        adjustedDistance = localDistance * 1.2; // Cycling routes are relatively direct
        localDuration = DistanceCalculator.calculateWalkingTimeMinutes(adjustedDistance * 0.4); // Cycling is faster
        break;
      case MapboxRouteType.driving:
      case MapboxRouteType.drivingTraffic:
        adjustedDistance = localDistance * 1.4; // Driving routes follow roads
        localDuration = DistanceCalculator.calculateDrivingTimeMinutes(adjustedDistance);
        break;
    }
    

    
    return {
      'distance': adjustedDistance,
      'duration': localDuration * 60.0, // Convert to seconds
      'formattedDistance': DistanceCalculator.formatDistance(adjustedDistance),
      'formattedDuration': '${localDuration}min',
      'durationMinutes': localDuration,
      'distanceKm': adjustedDistance / 1000,
      'source': 'local_adjusted',
    };
  }

  /// Get walking route information using Mapbox
  Future<Map<String, dynamic>> _getWalkingRouteInfo({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    // Validate and fix coordinate precision
    final validatedCoords = _validateAndFixCoordinates(startLat, startLng, endLat, endLng);
    
    return await _getMapboxRouteInfo(
      startLat: validatedCoords['startLat']!,
      startLng: validatedCoords['startLng']!,
      endLat: validatedCoords['endLat']!,
      endLng: validatedCoords['endLng']!,
      routeType: MapboxRouteType.walking,
    );
  }

  /// Validate and fix coordinate precision issues
  Map<String, double> _validateAndFixCoordinates(double startLat, double startLng, double endLat, double endLng) {
    // Round to 6 decimal places for consistency (approximately 1 meter precision)
    final roundedStartLat = double.parse(startLat.toStringAsFixed(6));
    final roundedStartLng = double.parse(startLng.toStringAsFixed(6));
    final roundedEndLat = double.parse(endLat.toStringAsFixed(6));
    final roundedEndLng = double.parse(endLng.toStringAsFixed(6));
    
    // Check if coordinates are identical (within 1 meter)
    final distance = DistanceCalculator.calculateDistance(roundedStartLat, roundedStartLng, roundedEndLat, roundedEndLng);
    
    
    return {
      'startLat': roundedStartLat,
      'startLng': roundedStartLng,
      'endLat': roundedEndLat,
      'endLng': roundedEndLng,
    };
  }

  /// Validate route request and provide fallback for invalid cases
  Map<String, dynamic> _validateRouteRequest(double startLat, double startLng, double endLat, double endLng, MapboxRouteType routeType) {
    // Check coordinate validity
    if (!DistanceCalculator.isValidCoordinate(startLat, startLng) || 
        !DistanceCalculator.isValidCoordinate(endLat, endLng)) {
      return {
        'isValid': false,
        'reason': 'Invalid coordinates',
        'fallbackResult': _createFallbackResult(0.0, routeType),
      };
    }
    
    // Calculate straight-line distance
    final distance = DistanceCalculator.calculateDistance(startLat, startLng, endLat, endLng);
    
    // Check for very short distances
    if (distance < 1.0) {
      return {
        'isValid': false,
        'reason': 'Distance too short (< 1m)',
        'fallbackResult': _createFallbackResult(distance, routeType),
      };
    }
    
    // Check for unreasonably long distances (more than 100km)
    if (distance > 100000) {
      return {
        'isValid': false,
        'reason': 'Distance too long (> 100km)',
        'fallbackResult': _createFallbackResult(distance, routeType),
      };
    }
    
    return {
      'isValid': true,
      'reason': 'Valid request',
      'fallbackResult': null,
    };
  }

  /// Create fallback result for invalid requests
  Map<String, dynamic> _createFallbackResult(double distance, MapboxRouteType routeType) {
    final adjustedDistance = distance * 1.3; // Apply road network factor
    final duration = _calculateFallbackDuration(adjustedDistance, routeType);
    
    return {
      'distance': adjustedDistance,
      'duration': duration * 60.0, // Convert to seconds
      'formattedDistance': DistanceCalculator.formatDistance(adjustedDistance),
      'formattedDuration': '${duration}min',
      'durationMinutes': duration,
      'distanceKm': adjustedDistance / 1000,
      'source': 'fallback',
    };
  }

  /// Calculate fallback duration based on route type
  int _calculateFallbackDuration(double distance, MapboxRouteType routeType) {
    switch (routeType) {
      case MapboxRouteType.walking:
        return DistanceCalculator.calculateWalkingTimeMinutes(distance);
      case MapboxRouteType.cycling:
        return DistanceCalculator.calculateCyclingTimeMinutes(distance);
      case MapboxRouteType.driving:
      case MapboxRouteType.drivingTraffic:
        return DistanceCalculator.calculateDrivingTimeMinutes(distance);
    }
  }

  /// Get driving distance to bus stop (using actual driving distance from API)
  String _getDrivingDistanceToBusStop() {
    if (_currentJourney == null) return '0.0';
    
   
    if (journeyDetails != null) {
      print('   drivingToBusStop available: ${journeyDetails!['drivingToBusStop'] != null}');
      if (journeyDetails!['drivingToBusStop'] != null) {
        final drivingData = journeyDetails!['drivingToBusStop'] as Map<String, dynamic>; 
     
      }
    }
    
    // Try to get the actual driving distance from the journey details
    if (journeyDetails != null && journeyDetails!['drivingToBusStop'] != null) {
      final drivingData = journeyDetails!['drivingToBusStop'] as Map<String, dynamic>;
      if (drivingData.containsKey('distance')) {
        final drivingDistance = drivingData['distance'] as double;
        final distanceKm = (drivingDistance / 1000).toStringAsFixed(1);
     
        return distanceKm;
      }
    }
    
    // Fallback to road network adjustment if API data not available
    final straightLineDistance = _currentJourney!.walkingDistanceToStart;
    final drivingDistance = straightLineDistance * 1.4; // Road network factor for driving
    final fallbackDistance = (drivingDistance / 1000).toStringAsFixed(1);
    

    
    return fallbackDistance;
  }

  /// Get driving time to bus stop (using local time calculation from Mapbox distance)
  int _getDrivingTimeToBusStop() {
    if (_currentJourney == null) return 0;
    
    // Use the pre-calculated time from the Journey model
    return _currentJourney!.walkingTimeToStart;
  }

  /// Get driving distance for bus journey (using actual driving distance from API)
  String _getDrivingDistanceForBusJourney() {
    if (_currentJourney == null) return '0.0';
    
    // Try to get the actual driving distance from the journey details
    if (journeyDetails != null && journeyDetails!['busJourney'] != null) {
      final drivingDistance = journeyDetails!['busJourney']['distance'] as double;
      return (drivingDistance / 1000).toStringAsFixed(1);
    }
    
    // Fallback to road network adjustment if API data not available
    final straightLineDistance = DistanceCalculator.calculateDistance(
      _currentJourney!.startStop.lat,
      _currentJourney!.startStop.lng,
      _currentJourney!.endStop.lat,
      _currentJourney!.endStop.lng,
    );
    
    // Apply road network adjustment for driving
    final drivingDistance = straightLineDistance * 1.4; // Road network factor for driving
    
    return (drivingDistance / 1000).toStringAsFixed(1);
  }

  /// Get driving time for bus journey (using local time calculation from Mapbox distance)
  int _getDrivingTimeForBusJourney() {
    if (_currentJourney == null) return 0;
    
    // Use the pre-calculated time from the Journey model
    return _currentJourney!.busTime;
  }

  /// Calculate total walking distance
  String _calculateTotalWalkingDistance() {
    if (_currentJourney == null) return '0.0';
    
    final totalWalkingDistance = _currentJourney!.walkingDistanceToStart + _currentJourney!.walkingDistanceFromEnd;
    return (totalWalkingDistance / 1000).toStringAsFixed(1);
  }

  /// Get driving route information using Mapbox
  Future<Map<String, dynamic>> _getDrivingRouteInfo({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    // Validate and fix coordinate precision
    final validatedCoords = _validateAndFixCoordinates(startLat, startLng, endLat, endLng);
    
    return await _getMapboxRouteInfo(
      startLat: validatedCoords['startLat']!,
      startLng: validatedCoords['startLng']!,
      endLat: validatedCoords['endLat']!,
      endLng: validatedCoords['endLng']!,
      routeType: MapboxRouteType.drivingTraffic,
    );
  }

  /// Get driving route information from user to bus stop (changed from walking)
  Future<Map<String, dynamic>> _getDrivingRouteToBusStop({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    // Validate and fix coordinate precision
    final validatedCoords = _validateAndFixCoordinates(startLat, startLng, endLat, endLng);
    
    return await _getMapboxRouteInfo(
      startLat: validatedCoords['startLat']!,
      startLng: validatedCoords['startLng']!,
      endLat: validatedCoords['endLat']!,
      endLng: validatedCoords['endLng']!,
      routeType: MapboxRouteType.driving, // Driving profile for road network distance
    );
  }

  Widget _buildActionButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              // Detail Bus Route Button
              Expanded(
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.only(right: 8),
                  child: ElevatedButton.icon(
                    onPressed: () => _showBusRouteDetails(),
                    icon: const Icon(Icons.directions_bus, color: Colors.white, size: 20),
                    label: Text(
                      'Detail Bus Route',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ),
              
              // Estimate Fare Button
              Expanded(
                child: Container(
                  height: 48,
                  margin: const EdgeInsets.only(left: 8),
                  child: ElevatedButton.icon(
                    onPressed: () => _showFareDialog(),
                    icon: const Icon(Icons.attach_money, color: Colors.white, size: 20),
                    label: Text(
                      'Estimate Fare',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Debug Distance Test Button (only in debug mode)
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: () => _testRouteFindingImprovements(),
                icon: const Icon(Icons.bug_report, color: Colors.white),
                label: Text(
                  'Test Route Finding',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showBusRouteDetails() {
    if (_currentJourney == null || _currentJourney!.routes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No route information available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Navigate to bus route details screen with journey information
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusRouteDetailsScreen(
          routeName: _currentJourney!.routes.first.name,
          startStop: _currentJourney!.startStop,
          endStop: _currentJourney!.endStop,
          journeyDetails: journeyDetails,
        ),
      ),
    );
  }

  void _showFareDialog() async {
    if (_currentJourney == null) return;
    
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Calculating fare...'),
          ],
        ),
      ),
    );
    
    final fareDetails = await _calculateFareDetails();
    
    // Close loading dialog
    Navigator.pop(context);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(20),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // Title
              Row(
                children: [
                  Icon(Icons.attach_money, color: const Color(0xFF4CAF50), size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fare Estimate',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Fare items
              _buildFareItem('BRT Bus', 'PKR 50', Icons.directions_bus, Colors.blue),
              const SizedBox(height: 12),
              if ((fareDetails['bykeaFare'] ?? 0) > 0) ...[
                _buildFareItem('Bykea', 'PKR ${fareDetails['bykeaFare']}', Icons.motorcycle, Colors.orange),
                const SizedBox(height: 12),
              ],
              if ((fareDetails['rickshawFare'] ?? 0) > 0) ...[
                _buildFareItem('Rickshaw', 'PKR ${fareDetails['rickshawFare']}', Icons.motorcycle, Colors.green),
                const SizedBox(height: 12),
              ],
              
              const Divider(height: 24),
              
              // Total
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calculate, color: const Color(0xFF4CAF50), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Total Estimated: PKR ${fareDetails['totalFare']}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Note
              Text(
                'Note: Fares may vary based on traffic and demand',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              
              // Close button
              SizedBox(
                width: double.infinity,
                child: TextButton(
            onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50).withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4CAF50),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFareItem(String title, String amount, IconData icon, Color color) {
    return Row(
          children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          amount,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<Map<String, int>> _calculateFareDetails() async {
    if (_currentJourney == null) {
      return {'totalFare': 0, 'bykeaFare': 0, 'rickshawFare': 0};
    }
    
    int totalFare = 50; // Base BRT fare
    int bykeaFare = 0;
    int rickshawFare = 0;
    
    // Calculate Bykea fare for getting to bus stop (same as 2nd card)
    final distanceToBusStop = _getDrivingDistanceToBusStopValue(); // Use driving distance like 2nd card
    if (distanceToBusStop > 0) {
      bykeaFare = DistanceCalculator.calculateBykeaFare(distanceToBusStop);
      totalFare += bykeaFare;
    }
    
    // Calculate fare for getting from bus stop to destination (if needed)
    final distanceFromBusStop = _currentJourney!.walkingDistanceFromEnd;
    final distanceInKm = distanceFromBusStop / 1000.0;
    
    if (distanceInKm >= 2.0 && distanceInKm < 4.0) {
      // Rickshaw for 2-4km
      rickshawFare = DistanceCalculator.calculateRickshawFare(distanceFromBusStop);
      totalFare += rickshawFare;
    } else if (distanceInKm >= 5.0) {
      // Bykea for 5km or more
      final additionalBykeaFare = DistanceCalculator.calculateBykeaFare(distanceFromBusStop);
      bykeaFare += additionalBykeaFare;
      totalFare += additionalBykeaFare;
    }
    
    return {
      'totalFare': totalFare,
      'bykeaFare': bykeaFare,
      'rickshawFare': rickshawFare,
    };
  }

  void _testRouteFindingImprovements() async {
    try {
      final routeFinder = context.read<RouteFinder>();
      await routeFinder.testRouteFindingImprovements();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route finding test completed. Check console for details.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Get driving distance to bus stop in meters (for transport suggestions)
  double _getDrivingDistanceToBusStopValue() {
    if (_currentJourney == null) return 0.0;
    
    // Try to get the actual driving distance from the journey details
    if (journeyDetails != null && journeyDetails!['drivingToBusStop'] != null) {
      final drivingDistance = journeyDetails!['drivingToBusStop']['distance'] as double;
      return drivingDistance;
    }
    
    // Fallback to road network adjustment if API data not available
    final straightLineDistance = _currentJourney!.walkingDistanceToStart;
    final drivingDistance = straightLineDistance * 1.4; // Road network factor for driving
    
    return drivingDistance;
  }

  double _getDrivingDistanceForBusJourneyValue() {
    if (_currentJourney == null) return 0.0;
    
    // Try to get the actual driving distance from the journey details
    if (journeyDetails != null && journeyDetails!['busJourney'] != null) {
      final drivingDistance = journeyDetails!['busJourney']['distance'] as double;
      return drivingDistance;
    }
    
    // Fallback to road network adjustment if API data not available
    final straightLineDistance = DistanceCalculator.calculateDistance(
      _currentJourney!.startStop.lat,
      _currentJourney!.startStop.lng,
      _currentJourney!.endStop.lat,
      _currentJourney!.endStop.lng,
    );
    
    // Apply road network adjustment for driving
    final drivingDistance = straightLineDistance * 1.4; // Road network factor for driving
    
    return drivingDistance;
  }
} 