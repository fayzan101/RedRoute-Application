import 'package:shared_preferences/shared_preferences.dart';

class TransportPreferenceService {
  static const String _preferenceKey = 'transport_preference';
  static const String _defaultPreference = 'Bykea';

  static Future<String> getTransportPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_preferenceKey) ?? _defaultPreference;
  }

  static Future<void> setTransportPreference(String preference) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, preference);
  }

  static Map<String, double> getFareRates() {
    return {
      'Bykea': 18.0, // PKR per km
      'Rickshaw': 25.0, // PKR per km
      'BRT': 50.0, // Fixed fare
    };
  }

  static double calculateFare(String transportType, double distanceInKm) {
    final rates = getFareRates();
    final rate = rates[transportType] ?? 0.0;
    
    if (transportType == 'BRT') {
      return rate; // Fixed fare
    }
    
    return rate * distanceInKm;
  }
} 