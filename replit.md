# RedRoute - Karachi Bus Navigation App

## Overview

RedRoute is a Flutter-based mobile application designed to help users navigate Karachi's RedBus (BRT) public transport system. The app provides intelligent route planning from the user's current location to their desired destination using the city's Bus Rapid Transit network. It integrates Mapbox for mapping and visualization, offering both walking directions and bus journey guidance with visual route display.

## System Architecture

### Frontend Architecture
- **Framework**: Flutter for cross-platform mobile development
- **UI Components**: Material Design components for consistent Android/iOS experience
- **State Management**: Flutter's built-in state management (likely StatefulWidget/Provider pattern)
- **Responsive Design**: Optimized for mobile devices with focus on Android deployment

### Mapping & Visualization
- **Mapping Service**: Mapbox GL JS integration via `mapbox_gl` Flutter plugin
- **Location Services**: `geolocator` package for GPS access and `permission_handler` for location permissions
- **Map Features**: 
  - Real-time user location tracking
  - BRT stop markers and route polylines
  - Interactive map with zoom and pan capabilities
  - Visual route planning with walking and transit segments

### Data Architecture
- **Primary Storage**: Static JSON files for BRT stop data (offline-first approach)
- **Data Structure**: Structured stop information including coordinates, names, IDs, and associated routes
- **Optional Backend**: Potential integration with FastAPI (Python) or Firebase Functions for dynamic data
- **Caching Strategy**: Local JSON assets for immediate app functionality without internet dependency

## Key Components

### Core Features
1. **Destination Input**: Search functionality for Karachi locations
2. **Route Planning Engine**: Algorithm to find optimal BRT connections
3. **Nearest Stop Detection**: Geospatial calculations to identify closest boarding/alighting points
4. **Multi-modal Directions**: Walking + bus journey + transfer guidance
5. **Visual Route Display**: Real-time map visualization with Mapbox integration

### Navigation Logic
- Current location detection via GPS
- Destination geocoding and validation
- BRT network analysis for route optimization
- Transfer point identification for multi-route journeys
- Last-mile transportation suggestions (walking, rickshaw, Bykea)

### User Interface Components
- Interactive map view with Mapbox GL
- Search input for destination selection
- Route information panels
- Step-by-step navigation instructions
- Real-time location tracking indicator

## Data Flow

1. **User Input**: User enters destination or selects from map
2. **Location Acquisition**: App requests and obtains current GPS coordinates
3. **Route Calculation**: 
   - Find nearest BRT stop to user's location
   - Identify BRT stop closest to destination
   - Calculate optimal route through BRT network
   - Determine any required transfers
4. **Route Presentation**: Display walking directions to boarding stop, bus route, and final walking segment
5. **Visual Mapping**: Render complete journey on Mapbox with markers and polylines
6. **Real-time Updates**: Continuously update user position and adjust guidance as needed

## External Dependencies

### Third-Party Services
- **Mapbox**: Mapping, geocoding, and routing services
- **Flutter Packages**:
  - `mapbox_gl`: Mapbox integration
  - `geolocator`: GPS location services
  - `permission_handler`: Device permission management

### Data Sources
- Static BRT stop database (JSON format)
- Mapbox tiles and geocoding API
- Device GPS for real-time positioning

### Optional Integrations
- Firebase (potential backend/analytics)
- FastAPI backend (future dynamic data updates)

## Deployment Strategy

### Primary Platform
- **Target**: Android devices (primary focus)
- **Distribution**: Google Play Store deployment expected
- **Web Support**: Flutter web capabilities included (index.html present)

### Deployment Configuration
- Web deployment ready with Mapbox GL JS integration
- Progressive Web App (PWA) capabilities via manifest.json
- Offline-first architecture for reliable operation in areas with poor connectivity

### Performance Considerations
- Local JSON data storage for fast app startup
- Efficient geospatial calculations for route planning
- Optimized map rendering with Mapbox GL

## Changelog

```
Changelog:
- July 01, 2025. Initial setup
```

## User Preferences

```
Preferred communication style: Simple, everyday language.
```