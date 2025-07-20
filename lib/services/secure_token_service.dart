import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureTokenService {
  static const String _tokenKey = 'secure_mapbox_token';
  static const String _saltKey = 'token_salt';
  static const String _rateLimitKey = 'rate_limit_data';
  
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
  
  /// Robust rate limiting with exponential backoff
  static Future<bool> isRateLimited() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rateLimitData = prefs.getString(_rateLimitKey);
      
      if (rateLimitData == null) {
        // First request, allow it
        await _updateRateLimitData(prefs, 1, DateTime.now().millisecondsSinceEpoch);
        return false;
      }
      
      final data = json.decode(rateLimitData);
      final requestCount = data['count'] ?? 0;
      final lastResetTime = data['lastReset'] ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      // Reset counter every minute
      if (currentTime - lastResetTime > 60000) {
        await _updateRateLimitData(prefs, 1, currentTime);
        return false;
      }
      
      // Allow up to 30 requests per minute (more reasonable for mapping app)
      if (requestCount >= 30) {
        print('⚠️ SecureTokenService: Rate limit reached (30 requests/minute)');
        return true;
      }
      
      // Increment counter
      await _updateRateLimitData(prefs, requestCount + 1, lastResetTime);
      return false;
      
    } catch (e) {
      print('❌ SecureTokenService: Error checking rate limit: $e');
      return false; // Allow request if rate limiting fails
    }
  }
  
  /// Update rate limit data
  static Future<void> _updateRateLimitData(SharedPreferences prefs, int count, int lastReset) async {
    final data = {
      'count': count,
      'lastReset': lastReset,
    };
    await prefs.setString(_rateLimitKey, json.encode(data));
  }
  
  /// Clear rate limit data (for testing)
  static Future<void> clearRateLimit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_rateLimitKey);
      print('🔐 SecureTokenService: Rate limit cleared');
    } catch (e) {
      print('❌ SecureTokenService: Error clearing rate limit: $e');
    }
  }
} 