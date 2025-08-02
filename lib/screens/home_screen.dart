import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/enhanced_location_service.dart';
import '../services/mapbox_service.dart';
import '../services/data_service.dart';
import '../services/theme_service.dart';
import '../services/route_finder.dart';
import '../widgets/karachi_location_search.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import 'route_details_screen.dart';
import 'bus_route_details_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    
    // Initialize screens with callbacks
    _screens = [
      const HomeTab(),
      MapTab(onBackPressed: () {
        print('Map back button pressed - switching to home tab');
        setState(() => _currentIndex = 0);
      }),
      RoutesTab(onBackPressed: () {
        print('Routes back button pressed - switching to home tab');
        setState(() => _currentIndex = 0);
      }),
      SettingsTab(onBackPressed: () {
        print('Settings back button pressed - switching to home tab');
        setState(() => _currentIndex = 0);
      }),
    ];
    
    // Set edge-to-edge mode to prevent navigation bar interference
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _initializeServices();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Or your custom color
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark ? Colors.black : Colors.white,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  Future<void> _initializeServices() async {
    final dataService = context.read<DataService>();
    
    // Load BRT data only - location will be fetched when user requests it
    try {
      await dataService.loadBRTData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading BRT data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFE53E3E),
        unselectedItemColor: Colors.black,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus),
            label: 'Routes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// Home Tab
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Column(
          children: [
            Text('RedRoute'),
            Text(
              'Karachi Bus Navigation',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Consumer<EnhancedLocationService>(
        builder: (context, locationService, child) {
          if (locationService.hasRequestedLocation && locationService.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Getting your location...'),
                ],
              ),
            );
          }

          if (locationService.hasRequestedLocation && locationService.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_off,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Location Error',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      locationService.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            locationService.clearError();
                            await locationService.initializeLocation();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            locationService.setFallbackLocation();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Using Karachi center as location. Routes may not be accurate.'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          },
                          icon: const Icon(Icons.location_on),
                          label: const Text('Use Karachi Center'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          return _buildMainContent(context, locationService);
        },
      ),
    );
  }

  void _navigateToRoute(BuildContext context, UnifiedPlace place) {
    // Check if location service is available
    try {
      final locationService = context.read<EnhancedLocationService>();
      final dataService = context.read<DataService>();
      
      if (locationService.currentPosition == null) {
        // Show dialog to let user choose what to do
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Not Available'),
            content: const Text(
              'Your current location is not available. You can:\n\n'
              '• Retry to get your location\n'
              '• Use Karachi center as your starting point\n'
              '• Cancel and try again later'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  locationService.clearError();
                  await locationService.initializeLocation();
                  // Try again after getting location
                  if (locationService.currentPosition != null) {
                    _navigateToRoute(context, place);
                  }
                },
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  locationService.setFallbackLocation();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Using Karachi center as location. Routes may not be accurate.'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  // Navigate with fallback location
                  _navigateToRoute(context, place);
                },
                child: const Text('Use Karachi Center'),
              ),
            ],
          ),
        );
        return;
      }

      // Navigate to route details screen with the selected place
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MultiProvider(
            providers: [
              ChangeNotifierProvider<EnhancedLocationService>.value(value: locationService),
              ChangeNotifierProvider<DataService>.value(value: dataService),
              ChangeNotifierProxyProvider<DataService, RouteFinder>(
                create: (context) => RouteFinder(dataService),
                update: (context, dataService, previous) => 
                  previous ?? RouteFinder(dataService),
              ),
            ],
            child: Builder(
              builder: (context) => RouteDetailsScreen(
                destinationLat: place.lat,
                destinationLng: place.lon,
                destinationName: place.displayName,
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      print('❌ Home: Error navigating to route: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildMainContent(BuildContext context, EnhancedLocationService locationService) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Enter Your Location Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar for location
                KarachiLocationSearch(
                  onPlaceSelected: (place) {
                    // Set the selected location as current location
                    final locationService = context.read<EnhancedLocationService>();
                    locationService.setCustomLocation(place.lat, place.lon);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Location set to: ${place.displayName}'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  onRouteRequested: (place) {
                    // Set the selected location as current location
                    final locationService = context.read<EnhancedLocationService>();
                    locationService.setCustomLocation(place.lat, place.lon);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Location set to: ${place.displayName}'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  hintText: 'From',
                  showPopularPlaces: false,
                  showSearchIcon: true,
                ),
                
                const SizedBox(height: 12),
                
                // Use Current Location Button
                Consumer<EnhancedLocationService>(
                  builder: (context, locationService, child) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: locationService.isLoading 
                          ? null 
                          : () async {
                              // Initialize location service when user clicks the button
                              await locationService.initializeLocation();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Using current location'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                        icon: locationService.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                        label: Text(
                          locationService.isLoading 
                            ? 'Detecting...' 
                            : 'Use Current Location',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Where do you want to go section
            Text(
              'Where do you want to go?',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Karachi Location Search
            KarachiLocationSearch(
              onPlaceSelected: (place) {
                // Directly navigate to route details when place is selected
                _navigateToRoute(context, place);
              },
              onRouteRequested: (place) => _navigateToRoute(context, place),
              hintText: 'Destination',
              showPopularPlaces: false,
              showSearchIcon: true,
            ),
            
            const SizedBox(height: 24),
            
            // Popular Places Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Popular Places',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                  children: [
                    _buildPopularPlaceCard(
                      context,
                      'Dolmen Mall',
                      'Clifton',
                      Icons.shopping_bag,
                      Colors.blue,
                      () => _navigateToRoute(context, UnifiedPlace(
                        name: 'Dolmen Mall',
                        displayName: 'Dolmen Mall, Clifton',
                        subtitle: 'Clifton',
                        lat: 24.8136,
                        lon: 67.0222,
                        type: 'shopping',
                      )),
                    ),
                    _buildPopularPlaceCard(
                      context,
                      'Port Grand',
                      'Karachi Port',
                      Icons.restaurant,
                      Colors.orange,
                      () => _navigateToRoute(context, UnifiedPlace(
                        name: 'Port Grand',
                        displayName: 'Port Grand',
                        subtitle: 'Karachi Port',
                        lat: 24.8500,
                        lon: 66.9900,
                        type: 'restaurant',
                      )),
                    ),
                    _buildPopularPlaceCard(
                      context,
                      'Beach View',
                      'Clifton Beach',
                      Icons.beach_access,
                      Colors.teal,
                      () => _navigateToRoute(context, UnifiedPlace(
                        name: 'Clifton Beach',
                        displayName: 'Clifton Beach',
                        subtitle: 'Clifton Beach',
                        lat: 24.8000,
                        lon: 67.0000,
                        type: 'beach',
                      )),
                    ),
                    _buildPopularPlaceCard(
                      context,
                      'Airport',
                      'Jinnah International',
                      Icons.flight,
                      Colors.purple,
                      () => _navigateToRoute(context, UnifiedPlace(
                        name: 'Jinnah International Airport',
                        displayName: 'Jinnah International Airport',
                        subtitle: 'Jinnah International',
                        lat: 24.9065,
                        lon: 67.1606,
                        type: 'airport',
                      )),
                    ),
                    _buildPopularPlaceCard(
                      context,
                      'Station',
                      'Karachi Cantt',
                      Icons.train,
                      Colors.green,
                      () => _navigateToRoute(context, UnifiedPlace(
                        name: 'Karachi Cantt Station',
                        displayName: 'Karachi Cantt Station',
                        subtitle: 'Karachi Cantt',
                        lat: 24.8600,
                        lon: 67.0500,
                        type: 'station',
                      )),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Current Location Section
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey.shade800 
                  : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade700
                    : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Location',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Consumer<EnhancedLocationService>(
                              builder: (context, locationService, child) {
                                final position = locationService.currentPosition;
                                if (position != null) {
                                  return FutureBuilder<String?>(
                                    future: MapboxService.getAddressFromCoordinates(
                                      position.latitude,
                                      position.longitude,
                                    ),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData && snapshot.data != null) {
                                        return Text(
                                          snapshot.data!,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        );
                                      }
                                      return Text(
                                        'Location available',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                        ),
                                      );
                                    },
                                  );
                                }
                                return Text(
                                  'Tap to get location',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Consumer<EnhancedLocationService>(
                        builder: (context, locationService, child) {
                          return IconButton(
                            onPressed: locationService.isLoading 
                              ? null 
                              : () async {
                                  await locationService.initializeLocation();
                                },
                            icon: locationService.isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.my_location, size: 20),
                            tooltip: 'Get current location',
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Information Card
            Card(
              color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.blue.shade900.withOpacity(0.3)
                : Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.blue.shade300
                            : Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'How it works',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.blue.shade300
                              : Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Enter your destination\n'
                      '2. We\'ll find the nearest BRT stop\n'
                      '3. Get step-by-step directions\n'
                      '4. Choose walking, rickshaw, or ride-hailing',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32), // Bottom padding for better scrolling
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildPopularPlaceCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Map Tab
class MapTab extends StatelessWidget {
  final VoidCallback? onBackPressed;
  
  const MapTab({super.key, this.onBackPressed});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapScreen(onBackPressed: onBackPressed),
    );
  }
}

// Routes Tab
class RoutesTab extends StatelessWidget {
  final VoidCallback? onBackPressed;
  
  const RoutesTab({super.key, this.onBackPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (onBackPressed != null) {
              onBackPressed!();
            } else {
              // Fallback: navigate back
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text('BRT Routes'),
        centerTitle: true,
        actions: [
          Icon(
            Icons.directions_bus,
            color: const Color(0xFFE92929),
            size: 28,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            
            // Routes List
            Expanded(
              child: Consumer<DataService>(
                builder: (context, dataService, child) {
                  final routes = dataService.getSortedRouteNames();
                  
                                    if (routes.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: const Color(0xFFE92929),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading routes...',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: routes.length,
                    itemBuilder: (context, index) {
                      final route = dataService.getRouteByName(routes[index]);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade800 : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark 
                                  ? Colors.black.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE92929),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                routes[index].split(' ').last,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            routes[index],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF181111),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${route?.stops.length ?? 0} stops',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                              if (route?.stops.isNotEmpty == true) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${route!.stops.first.name} → ${route.stops.last.name}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          onTap: () {
                            // Navigate to route details
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BusRouteDetailsScreen(
                                  routeName: routes[index],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Settings Tab
class SettingsTab extends StatelessWidget {
  final VoidCallback? onBackPressed;
  
  const SettingsTab({super.key, this.onBackPressed});

  @override
  Widget build(BuildContext context) {
    return SettingsScreen(onBackPressed: onBackPressed);
  }
}
