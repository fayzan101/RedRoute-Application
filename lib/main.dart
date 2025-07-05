import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/map_search_screen.dart';
import 'screens/route_details_screen.dart';
import 'services/location_service.dart';
import 'services/data_service.dart';
import 'services/route_finder.dart';
import 'models/route.dart';

void main() {
  runApp(const RedRouteApp());
}

class RedRouteApp extends StatelessWidget {
  const RedRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => DataService()),
        ChangeNotifierProxyProvider<DataService, RouteFinder>(
          create: (context) => RouteFinder(context.read<DataService>()),
          update: (context, dataService, previous) => 
            previous ?? RouteFinder(dataService),
        ),
      ],
      child: MaterialApp(
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
        '/route-details': (context) {
          final journey = ModalRoute.of(context)!.settings.arguments as Journey?;
          return RouteDetailsScreen(journey: journey);
        },
        '/home': (context) => const HomeScreen(), // Use proper home screen with tabs
      },
      debugShowCheckedModeBanner: false,
      ),
    );
  }
}


