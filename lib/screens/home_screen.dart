import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/location_service.dart';
import '../services/geocoding_service.dart';
import '../services/data_service.dart';
import '../services/theme_service.dart';
import '../widgets/destination_search.dart';
import 'map_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeTab(),
    const MapTab(),
    const RoutesTab(),
    const SettingsTab(),
  ];

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
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final locationService = context.read<LocationService>();
    final dataService = context.read<DataService>();
    
    // Initialize location service
    await locationService.initializeLocation();
    
    // Load BRT data
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
        selectedItemColor: const Color(0xFFE53E3E),
        unselectedItemColor: Colors.grey,
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
      body: Consumer<LocationService>(
        builder: (context, locationService, child) {
          if (locationService.isLoading) {
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

          if (locationService.error != null) {
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
                    ElevatedButton.icon(
                      onPressed: () async {
                        locationService.clearError();
                        await locationService.initializeLocation();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
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

  Widget _buildMainContent(BuildContext context, LocationService locationService) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Current Location',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Consumer<LocationService>(
                          builder: (context, locationService, child) {
                            return IconButton(
                              onPressed: locationService.isLoading 
                                ? null 
                                : () async {
                                    await locationService.getCurrentLocation();
                                  },
                              icon: locationService.isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh, size: 20),
                              tooltip: 'Refresh location',
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Consumer<LocationService>(
                      builder: (context, locationService, child) {
                        final position = locationService.currentPosition;
                        if (position != null) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lat: ${position.latitude.toStringAsFixed(4)}, '
                                'Lng: ${position.longitude.toStringAsFixed(4)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              FutureBuilder<String?>(
                                future: GeocodingService.getAddressFromCoordinates(
                                  position.latitude,
                                  position.longitude,
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Text(
                                      'Getting address...',
                                      style: TextStyle(color: Colors.grey, fontSize: 12),
                                    );
                                  }
                                  if (snapshot.hasData && snapshot.data != null) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          snapshot.data!,
                                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Accuracy: ${position.accuracy.toStringAsFixed(1)}m',
                                          style: const TextStyle(color: Colors.blue, fontSize: 10),
                                        ),
                                      ],
                                    );
                                  }
                                  return const Text(
                                    'Address not available',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  );
                                },
                              ),
                            ],
                          );
                        }
                        return const Text(
                          'Location not available',
                          style: TextStyle(color: Colors.grey),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Destination Search
            Text(
              'Where do you want to go?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            
            // Destination Search
            const DestinationSearch(),
            
            const SizedBox(height: 32),
            
            // Information Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'How it works',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Enter your destination\n'
                      '2. We\'ll find the nearest BRT stop\n'
                      '3. Get step-by-step directions\n'
                      '4. Choose walking, rickshaw, or ride-hailing',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32), // Bottom padding for better scrolling
          ],
        ),
      ),
    );
  }
}

// Map Tab
class MapTab extends StatelessWidget {
  const MapTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const MapScreen();
  }
}

// Routes Tab
class RoutesTab extends StatelessWidget {
  const RoutesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BRT Routes'),
      ),
      body: Consumer<DataService>(
        builder: (context, dataService, child) {
          final routes = dataService.getAllRouteNames();
          
          if (routes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading routes...'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: routes.length,
            itemBuilder: (context, index) {
              final route = dataService.getRouteByName(routes[index]);
              return Card(
                margin: const EdgeInsets.only(bottom: 12.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      routes[index].split(' ').last,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    routes[index],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${route?.stops.length ?? 0} stops'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Navigate to route details
                    Navigator.pushNamed(context, '/route-details');
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Settings Tab
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen();
  }
}
