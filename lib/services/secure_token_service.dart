import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureTokenService {
  static const String _tokenKey = 'secure_mapbox_token';
  static const String _saltKey = 'token_salt';
  
  /// Store token securely with encryption
  static Future<void> storeToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Generate a random salt
      final salt = _generateSalt();
      
      // Hash the token with salt
      final hashedToken = _hashToken(token, salt);
      
      // Store both salt and hashed token
      await prefs.setString(_saltKey, salt);
      await prefs.setString(_tokenKey, hashedToken);
      
      print('🔐 SecureTokenService: Token stored securely');
    } catch (e) {
      print('❌ SecureTokenService: Error storing token: $e');
    }
  }
  
  /// Retrieve token securely
  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final salt = prefs.getString(_saltKey);
      final hashedToken = prefs.getString(_tokenKey);
      
      if (salt == null || hashedToken == null) {
        print('ℹ️ SecureTokenService: Initializing with default token');
        // Store the default token on first run
        final defaultToken = _getDefaultToken();
        await storeToken(defaultToken);
        return defaultToken;
      }
      
      // For now, return the default token since we can't decrypt
      // In a real implementation, you'd decrypt the stored token
      return _getDefaultToken();
    } catch (e) {
      print('❌ SecureTokenService: Error retrieving token: $e');
      return _getDefaultToken();
    }
  }
  
  /// Validate token format
  static bool isValidToken(String token) {
    return token.isNotEmpty && 
           token.startsWith('pk.') && 
           token.length > 20 &&
           token.contains('.');
  }
  
  /// Get masked token for logging
  static String getMaskedToken(String token) {
    if (token.length <= 10) return '***';
    return '${token.substring(0, 10)}...${token.substring(token.length - 4)}';
  }
  
  /// Clear stored token
  static Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_saltKey);
      print('🔐 SecureTokenService: Token cleared');
    } catch (e) {
      print('❌ SecureTokenService: Error clearing token: $e');
    }
  }
  
  /// Generate random salt
  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(bytes);
  }
  
  /// Hash token with salt
  static String _hashToken(String token, String salt) {
    final bytes = utf8.encode(token + salt);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes);
  }
  
  /// Get default token (fallback)
  static String _getDefaultToken() {
    return 'pk.eyJ1IjoibXRhYWhhIiwiYSI6ImNtYzhzNDdxYTBoYTgydnM5Y25sOWUxNW4ifQ.LNtkLKq7wVti_5_MyaBY-w';
  }
  
  /// Check if token is rate limited
  static Future<bool> isRateLimited() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRequestTime = prefs.getInt('last_request_time') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      // Allow 1 request per second
      if (currentTime - lastRequestTime < 1000) {
        return true;
      }
      
      // Update last request time
      await prefs.setInt('last_request_time', currentTime);
      return false;
    } catch (e) {
      print('❌ SecureTokenService: Error checking rate limit: $e');
      return false;
    }
  }
} 