import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/location_service.dart';
import 'services/data_service.dart';
import 'services/route_finder.dart';

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
        Provider(create: (_) => DataService()),
        Provider(create: (context) => RouteFinder(context.read<DataService>())),
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
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
