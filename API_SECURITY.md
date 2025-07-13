# API Security Implementation

## Overview
This document explains how the Mapbox API token is secured in the RedRoute app.

## Security Features Implemented

### 1. Environment-Based Configuration
- API tokens are loaded from environment variables
- Fallback to default token if environment variable is not set
- Token validation and masking for logging

### 2. Secure Token Storage
- Tokens are hashed with salt before storage
- Uses SharedPreferences with encryption
- Rate limiting to prevent abuse

### 3. Token Validation
- Validates token format (starts with 'pk.')
- Checks token length and structure
- Provides masked tokens for logging

## How to Use

### Option 1: Environment Variable (Recommended)
When building the app, pass the Mapbox token as an environment variable:

```bash
flutter build apk --dart-define=MAPBOX_ACCESS_TOKEN=your_actual_token_here
```

### Option 2: Update Default Token
If you prefer to hardcode the token (less secure), update the default value in:
`lib/config/api_config.dart`

```dart
static const String mapboxAccessToken = String.fromEnvironment(
  'MAPBOX_ACCESS_TOKEN',
  defaultValue: 'your_actual_token_here', // Replace this
);
```

### Option 3: Runtime Token Storage
Use the SecureTokenService to store tokens at runtime:

```dart
await SecureTokenService.storeToken('your_actual_token_here');
```

## Security Best Practices

1. **Never commit tokens to version control**
2. **Use environment variables for production builds**
3. **Rotate tokens regularly**
4. **Monitor API usage for unusual patterns**
5. **Use rate limiting to prevent abuse**

## Files Modified

- `lib/config/api_config.dart` - Centralized API configuration
- `lib/services/secure_token_service.dart` - Secure token management
- `lib/services/mapbox_service.dart` - Updated to use secure tokens
- `pubspec.yaml` - Added crypto dependency

## Token Validation

The app validates tokens using:
- Format check (starts with 'pk.')
- Length validation (> 20 characters)
- Structure validation (contains '.')

## Rate Limiting

The app implements rate limiting:
- 1 request per second maximum
- Automatic request tracking
- Graceful degradation when rate limited

## Logging Security

All API requests log masked tokens:
- Original: `pk.eyJ1IjoibXRhYWhhIiwiYSI6ImNtYzhzNDdxYTBoYTgydnM5Y25sOWUxNW4ifQ.LNtkLKq7wVti_5_MyaBY-w`
- Logged: `pk.eyJ1Ijoi...BY-w`

## Troubleshooting

### Token Not Working
1. Check if token is valid format
2. Verify token has proper permissions
3. Check rate limiting status
4. Review API usage limits

### Build Errors
1. Ensure crypto dependency is added
2. Check environment variable syntax
3. Verify token format

## Production Deployment

For production deployment:
1. Use environment variables
2. Enable proper logging
3. Monitor API usage
4. Set up token rotation schedule
5. Configure rate limiting appropriately 