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
      // Add timeout to prevent infinite loading
      final journey = await routeFinder.findBestRoute(
        userLat: userPosition.latitude,
        userLng: userPosition.longitude,
        destLat: widget.destinationLat!,
        destLng: widget.destinationLng!,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Route finding timed out. Please try again.');
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finding route: $e'),
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
      body: SafeArea(
        child: Column(
        children: [
          // Header
          Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                    'Journey Details',
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
                _buildTransportSuggestions(_currentJourney?.walkingDistanceToStart ?? 0, 'start'),
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
                  title: 'Journey Time',
                  value: '${_calculateBusTime()} min',
                  color: Colors.blue.shade600,
                ),
              ),
              Expanded(
                child: _buildJourneyMetric(
                  icon: Icons.straighten,
                  title: 'Journey Distance',
                  value: '${_calculateBusDistance()} km',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Widget> suggestions = [];
    
    // Walking suggestion (always available)
    final walkingTime = DistanceCalculator.calculateWalkingTimeMinutes(distance);
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
      final rickshawTime = DistanceCalculator.calculateDrivingTimeMinutes(
        distanceInMeters: distance,
        vehicleType: 'rickshaw',
        departureTime: DateTime.now(),
      );
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
      final bykeaTime = DistanceCalculator.calculateDrivingTimeMinutes(
        distanceInMeters: distance,
        vehicleType: 'bykea',
        departureTime: DateTime.now(),
      );
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



  Widget _buildActionButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
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
    
    // Navigate to bus route details screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusRouteDetailsScreen(
          routeName: _currentJourney!.routes.first.name,
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
    
    // Get user's transport preference
    final userPreference = await TransportPreferenceService.getTransportPreference();
    
    // Calculate fare for getting to bus stop (if needed)
    final distanceToBusStop = _currentJourney!.walkingDistanceToStart;
    if (distanceToBusStop > 1000) { // If more than 1km, suggest transport
      final transportDistance = distanceToBusStop / 1000; // Convert to km
      
      if (userPreference == 'Bykea') {
        bykeaFare = TransportPreferenceService.calculateFare('Bykea', transportDistance).round();
        totalFare += bykeaFare;
      } else if (userPreference == 'Rickshaw') {
        rickshawFare = TransportPreferenceService.calculateFare('Rickshaw', transportDistance).round();
        totalFare += rickshawFare;
      }
      // If preference is 'Walk', no additional fare
    }
    
    // Calculate fare for getting from bus stop to destination
    final distanceFromBusStop = _currentJourney!.walkingDistanceFromEnd;
    if (distanceFromBusStop > 1000) { // If more than 1km, suggest transport
      final transportDistance = distanceFromBusStop / 1000; // Convert to km
      
      if (userPreference == 'Bykea') {
        final additionalFare = TransportPreferenceService.calculateFare('Bykea', transportDistance).round();
        bykeaFare += additionalFare;
        totalFare += additionalFare;
      } else if (userPreference == 'Rickshaw') {
        final additionalFare = TransportPreferenceService.calculateFare('Rickshaw', transportDistance).round();
        rickshawFare += additionalFare;
        totalFare += additionalFare;
      }
      // If preference is 'Walk', no additional fare
    }
    
    return {
      'totalFare': totalFare,
      'bykeaFare': bykeaFare,
      'rickshawFare': rickshawFare,
    };
  }
} 