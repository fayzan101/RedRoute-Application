import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';



import 'screens/route_details_screen.dart';
import 'services/enhanced_location_service.dart';
import 'services/data_service.dart';
import 'services/route_finder.dart';
import 'services/theme_service.dart';
import 'services/json_places_service.dart';
import 'services/mapbox_service.dart';
import 'services/mapbox_service.dart';
import 'services/recent_searches_service.dart';
import 'services/secure_token_service.dart';
import 'services/transport_preference_service.dart';
import 'utils/distance_calculator.dart';
import 'models/route.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize JSON places service
  try {
    await JsonPlacesService.loadPlaces();
    print('✅ Main: JSON places service initialized successfully');
  } catch (e) {
    print('❌ Main: Error initializing JSON places service: $e');
  }
  
  // Pre-initialize Mapbox service to avoid first-time failures
  try {
    final mapboxInitialized = await MapboxService.initialize();
    if (mapboxInitialized) {
      print('✅ Main: Mapbox service pre-initialized successfully');
    } else {
      print('⚠️ Main: Mapbox service pre-initialization failed, but app will continue');
    }
  } catch (e) {
    print('❌ Main: Error pre-initializing Mapbox service: $e');
  }
  
  // Set system UI mode for the entire app
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(const RedRouteApp());
}

class RedRouteApp extends StatelessWidget {
  const RedRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EnhancedLocationService()),
        ChangeNotifierProvider(create: (_) => DataService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProxyProvider<DataService, RouteFinder>(
          create: (context) => RouteFinder(context.read<DataService>()),
          update: (context, dataService, previous) => 
            previous ?? RouteFinder(dataService),
        ),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) => MaterialApp(
        title: 'RedRoute - Karachi Bus Navigation',
        theme: themeService.currentTheme,
      // Simplified routing for testing
      home: const SplashScreen(),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/route-details': (context) {
          final journey = ModalRoute.of(context)!.settings.arguments as Journey?;
          return RouteDetailsScreen(journey: journey);
        },
        '/home': (context) => const HomeScreen(), // Use proper home screen with tabs
      },
      debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}


