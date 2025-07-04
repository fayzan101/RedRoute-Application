import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';  // Temporarily disabled
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/map_search_screen.dart';
import 'screens/route_details_screen.dart';
// import 'services/location_service.dart';  // Temporarily disabled
// import 'services/data_service.dart';      // Temporarily disabled
// import 'services/route_finder.dart';      // Temporarily disabled

void main() {
  runApp(const RedRouteApp());
}

class RedRouteApp extends StatelessWidget {
  const RedRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RedRoute - Karachi Bus Navigation',
      theme: ThemeData(
        primarySwatch: Colors.red,
        primaryColor: const Color(0xFFE53E3E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53E3E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFE53E3E),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53E3E),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      // Simplified routing for testing
      home: const SplashScreen(),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/map-search': (context) => const MapSearchScreen(),
        '/route-details': (context) => const RouteDetailsScreen(),
        '/home': (context) => const TestHomeScreen(), // Simplified home
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// Simplified test home screen
class TestHomeScreen extends StatelessWidget {
  const TestHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('RedRoute - Test Mode'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_bus,
              size: 64,
              color: Color(0xFFE53E3E),
            ),
            const SizedBox(height: 16),
            const Text(
              'RedRoute Test Mode',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF181111),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'App is working! 🎉',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF886363),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/welcome'),
              child: const Text('Test Welcome Screen'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/map-search'),
              child: const Text('Test Map Search'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/route-details'),
              child: const Text('Test Route Details'),
            ),
          ],
        ),
      ),
    );
  }
}
