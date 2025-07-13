class ApiConfig {
  // Mapbox API Configuration
  static const String mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: 'pk.eyJ1IjoibXRhYWhhIiwiYSI6ImNtYzhzNDdxYTBoYTgydnM5Y25sOWUxNW4ifQ.LNtkLKq7wVti_5_MyaBY-w',
  );
  
  // Base URLs
  static const String mapboxBaseUrl = 'https://api.mapbox.com';
  
  // API Endpoints
  static const String mapboxGeocodingEndpoint = '/geocoding/v5/mapbox.places';
  static const String mapboxDirectionsEndpoint = '/directions/v5/mapbox/driving';
  
  // Default parameters
  static const String karachiBbox = '66.8,24.7,67.4,25.2'; // Karachi bounding box
  static const String pakistanCountryCode = 'pk';
  
  // Rate limiting and caching
  static const int maxRequestsPerMinute = 60;
  static const Duration cacheDuration = Duration(minutes: 30);
  
  // Validation
  static bool get isMapboxTokenValid {
    return mapboxAccessToken.isNotEmpty && 
           mapboxAccessToken.startsWith('pk.') && 
           mapboxAccessToken.length > 20;
  }
  
  // Security check
  static String get maskedToken {
    if (mapboxAccessToken.length <= 10) return '***';
    return '${mapboxAccessToken.substring(0, 10)}...${mapboxAccessToken.substring(mapboxAccessToken.length - 4)}';
  }
} 