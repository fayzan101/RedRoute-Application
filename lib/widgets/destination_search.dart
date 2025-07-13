import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../services/enhanced_location_service.dart';
import '../services/mapbox_service.dart';
import '../services/recent_searches_service.dart';
import '../models/stop.dart';
import '../screens/map_screen.dart';
import '../screens/route_details_screen.dart';

enum SearchResultType { brtStop, generalLocation }

class SearchResult {
  final String name;
  final String subtitle;
  final double latitude;
  final double longitude;
  final SearchResultType type;
  final Stop? stop; // Only for BRT stops
  final Map<String, dynamic>? location; // Only for general locations

  SearchResult({
    required this.name,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.stop,
    this.location,
  });

  factory SearchResult.fromStop(Stop stop) {
    return SearchResult(
      name: stop.name,
      subtitle: 'BRT Stop • Routes: ${stop.routes.join(", ")}',
      latitude: stop.lat,
      longitude: stop.lng,
      type: SearchResultType.brtStop,
      stop: stop,
    );
  }

  factory SearchResult.fromLocation(Map<String, dynamic> location) {
    String name = location['name'] ?? 'Unknown Location';
    String formattedAddress = location['formattedAddress'] ?? name;
    
    // Create a better subtitle from Mapbox data
    String subtitle = 'Location';
    String type = location['type'] ?? 'unknown';
    
    // Extract location info from formatted address
    if (formattedAddress.isNotEmpty) {
      final parts = formattedAddress.split(', ');
      if (parts.length > 1) {
        // Try to get the area/locality from the address
        for (int i = 1; i < parts.length; i++) {
          String part = parts[i].trim();
          if (part.isNotEmpty && part != 'Karachi' && part != 'Pakistan') {
            subtitle = part;
            break;
          }
        }
      }
    }
    
    // Add type information to subtitle
    if (type != 'unknown') {
      subtitle = '$subtitle • ${type.toUpperCase()}';
    }
    
    return SearchResult(
      name: name,
      subtitle: subtitle,
      latitude: location['latitude'] ?? 0.0,
      longitude: location['longitude'] ?? 0.0,
      type: SearchResultType.generalLocation,
      location: location,
    );
  }
}

class DestinationSearch extends StatefulWidget {
  const DestinationSearch({super.key});

  @override
  State<DestinationSearch> createState() => _DestinationSearchState();
}

class _DestinationSearchState extends State<DestinationSearch> {
  final TextEditingController _controller = TextEditingController();
  final RecentSearchesService _recentSearchesService = RecentSearchesService();
  SearchResult? _selectedDestination;
  List<RecentSearch> _recentSearches = [];
  bool _showRecentSearches = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final searches = await _recentSearchesService.getRecentSearches();
    setState(() {
      _recentSearches = searches;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TypeAheadField<SearchResult>(
              controller: _controller,
              debounceDuration: const Duration(milliseconds: 300),
              animationDuration: const Duration(milliseconds: 300),
              builder: (context, controller, focusNode) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Search all locations in Karachi (places, areas, BRT stops)...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _selectedDestination = null;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                );
              },
              suggestionsCallback: (pattern) async {
                if (pattern.length < 1) {
                  // Show recent searches when search box is empty and focused
                  setState(() {
                    _showRecentSearches = true;
                  });
                  return [];
                }
                
                setState(() {
                  _showRecentSearches = false;
                });
                
                try {
                  final List<SearchResult> results = [];
                  
                  // Add instant suggestions for common searches
                  results.addAll(_getInstantSuggestions(pattern));
                  
                  // Search both BRT stops and general locations simultaneously
                  List<SearchResult> brtResults = [];
                  List<SearchResult> locationResults = [];
                  
                  // Search BRT stops (local search)
                  try {
                    final dataService = context.read<DataService>();
                    await dataService.loadBRTData();
                    final brtStops = dataService.searchStops(pattern);
                    brtResults = brtStops.take(3).map((stop) => SearchResult.fromStop(stop)).toList();
                  } catch (e) {
                    print('Error loading BRT stops: $e');
                  }
                  
                  // Search general Karachi locations using Mapbox API (for all patterns)
                  try {
                    final locations = await MapboxService.searchPlaces(pattern);
                    locationResults = locations.take(7).map((location) => SearchResult.fromLocation(location)).toList();
                  } catch (e) {
                    print('Error searching locations: $e');
                  }
                  
                  // Combine and sort results by relevance
                  results.addAll(brtResults);
                  results.addAll(locationResults);
                  
                  // Sort results to prioritize better matches
                  results.sort((a, b) {
                    // First, prioritize exact matches
                    final aExactMatch = a.name.toLowerCase().contains(pattern.toLowerCase());
                    final bExactMatch = b.name.toLowerCase().contains(pattern.toLowerCase());
                    
                    if (aExactMatch && !bExactMatch) return -1;
                    if (!aExactMatch && bExactMatch) return 1;
                    
                    // Then prioritize BRT stops for bus-related queries
                    if (pattern.toLowerCase().contains('bus') || 
                        pattern.toLowerCase().contains('brt') ||
                        pattern.toLowerCase().contains('stop')) {
                      if (a.type == SearchResultType.brtStop && b.type != SearchResultType.brtStop) return -1;
                      if (a.type != SearchResultType.brtStop && b.type == SearchResultType.brtStop) return 1;
                    }
                    
                    return 0;
                  });
                  
                  return results.take(10).toList(); // Return top 10 results
                } catch (e) {
                  print('General search error: $e');
                  return [];
                }
              },
              itemBuilder: (context, SearchResult suggestion) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: suggestion.type == SearchResultType.brtStop 
                        ? Theme.of(context).primaryColor 
                        : Colors.blue,
                    child: Icon(
                      suggestion.type == SearchResultType.brtStop 
                          ? Icons.directions_bus 
                          : Icons.place,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(suggestion.name),
                  subtitle: Text(
                    suggestion.subtitle,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  trailing: Icon(
                    suggestion.type == SearchResultType.brtStop 
                        ? Icons.directions_bus_filled 
                        : Icons.location_on,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                );
              },
              onSelected: (SearchResult suggestion) async {
                setState(() {
                  _selectedDestination = suggestion;
                  _controller.text = suggestion.name;
                });
                
                // Save to recent searches
                await _recentSearchesService.addRecentSearch(RecentSearch(
                  query: suggestion.name,
                  name: suggestion.name,
                  subtitle: suggestion.subtitle,
                  latitude: suggestion.latitude,
                  longitude: suggestion.longitude,
                  timestamp: DateTime.now(),
                ));
                
                // Automatically navigate to route when destination is selected
                _navigateToRoute();
              },
              emptyBuilder: (context) => _showRecentSearches && _recentSearches.isNotEmpty
                  ? _buildRecentSearchesList()
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No results found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try searching for:\n• Places (e.g., "Dolmen Mall", "Port Grand")\n• Areas (e.g., "Clifton", "Gulshan", "Saddar")\n• Universities (e.g., "FAST", "KU")\n• BRT stops (e.g., "FTC", "Tower")',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
              loadingBuilder: (context) => const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Searching...'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showMapPicker(),
                    icon: const Icon(Icons.map),
                    label: const Text('Pick on Map'),
                  ),
                ),
              ],
            ),
            // Selected destination info
            if (_selectedDestination != null) ...[
              const SizedBox(height: 16),
              _buildSelectedDestinationCard(),
            ],
            // Quick destination suggestions
            const SizedBox(height: 24),
            _buildQuickSuggestions(),
            const SizedBox(height: 16), // Bottom padding for better scrolling
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDestinationCard() {
    if (_selectedDestination == null) return const SizedBox();

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Selected Destination',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _selectedDestination!.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedDestination!.subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Coordinates: ${_selectedDestination!.latitude.toStringAsFixed(4)}, ${_selectedDestination!.longitude.toStringAsFixed(4)}',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToRoute(),
                icon: const Icon(Icons.directions),
                label: const Text('Get Route'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular Destinations',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        
        // Popular BRT Stops
        Text(
          'Popular BRT Stops',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Consumer<DataService>(
          builder: (context, dataService, child) {
            final popularStops = dataService.stops.take(4).toList();
            
            if (popularStops.isEmpty) {
              return const SizedBox();
            }

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: popularStops.map((stop) {
                return ActionChip(
                  avatar: Icon(
                    Icons.directions_bus,
                    size: 18,
                    color: Theme.of(context).primaryColor,
                  ),
                  label: Text(
                    stop.name,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedDestination = SearchResult.fromStop(stop);
                      _controller.text = stop.name;
                    });
                    _navigateToRoute();
                  },
                );
              }).toList(),
            );
          },
        ),
        
        const SizedBox(height: 16),
        
        // Popular Karachi Locations
        Text(
          'Popular Places',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildLocationChip('Dolmen Mall Clifton', 24.8125, 67.0222),
            _buildLocationChip('Port Grand', 24.8133, 67.0222),
            _buildLocationChip('FAST University', 24.8607, 67.0011),
            _buildLocationChip('Clifton Beach', 24.8133, 67.0222),
            _buildLocationChip('Karachi Airport', 24.9065, 67.1606),
            _buildLocationChip('dar', 24.8607, 67.0011),
            _buildLocationChip('Gulshan-e-Iqbal', 24.9333, 67.1167),
            _buildLocationChip('Aga Khan Hospital', 24.8607, 67.0011),
            _buildLocationChip('Karachi Zoo', 24.8607, 67.0011),
            _buildLocationChip('Nazimabad', 24.9333, 67.1167),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationChip(String name, double lat, double lng) {
    return ActionChip(
      avatar: Icon(
        Icons.place,
        size: 18,
        color: Colors.blue,
      ),
      label: Text(
        name,
        style: const TextStyle(fontSize: 12),
      ),
      onPressed: () {
        setState(() {
          _selectedDestination = SearchResult(
            name: name,
            subtitle: 'Popular Location • Karachi',
            latitude: lat,
            longitude: lng,
            type: SearchResultType.generalLocation,
            location: {
              'name': name,
              'latitude': lat,
              'longitude': lng,
            },
          );
          _controller.text = name;
        });
        _navigateToRoute();
      },
    );
  }

  List<SearchResult> _getInstantSuggestions(String pattern) {
    final lowercasePattern = pattern.toLowerCase();
    final List<SearchResult> suggestions = [];
    
    // Common Karachi locations with coordinates
    final Map<String, Map<String, dynamic>> commonLocations = {
      // Universities
      'fast': {
        'name': 'FAST University',
        'lat': 24.8607,
        'lng': 67.0011,
        'subtitle': 'University • Karachi',
      },
      'uni': {
        'name': 'FAST University',
        'lat': 24.8607,
        'lng': 67.0011,
        'subtitle': 'University • Karachi',
      },
      'ku': {
        'name': 'University of Karachi',
        'lat': 24.9434,
        'lng': 67.1145,
        'subtitle': 'University • Karachi',
      },
      'ned': {
        'name': 'NED University',
        'lat': 24.9333,
        'lng': 67.1167,
        'subtitle': 'University • Karachi',
      },
      
      // Shopping Malls
      'dolmen': {
        'name': 'Dolmen Mall Clifton',
        'lat': 24.8125,
        'lng': 67.0222,
        'subtitle': 'Shopping Mall • Clifton',
      },
      'ocean': {
        'name': 'Ocean Mall',
        'lat': 24.8133,
        'lng': 67.0222,
        'subtitle': 'Shopping Mall • Clifton',
      },
      'park': {
        'name': 'Park Towers',
        'lat': 24.8133,
        'lng': 67.0222,
        'subtitle': 'Shopping Mall • Clifton',
      },
      
      // Entertainment
      'port': {
        'name': 'Port Grand',
        'lat': 24.8133,
        'lng': 67.0222,
        'subtitle': 'Entertainment • Karachi Port',
      },
      'beach': {
        'name': 'Clifton Beach',
        'lat': 24.8133,
        'lng': 67.0222,
        'subtitle': 'Beach • Clifton',
      },
      'zoo': {
        'name': 'Karachi Zoo',
        'lat': 24.8607,
        'lng': 67.0011,
        'subtitle': 'Zoo • Garden East',
      },
      
      // Areas
      'defence': {
        'name': 'Defence Housing Authority',
        'lat': 24.8133,
        'lng': 67.0222,
        'subtitle': 'Residential Area • Karachi',
      },
      'clifton': {
        'name': 'Clifton',
        'lat': 24.8133,
        'lng': 67.0222,
        'subtitle': 'Area • Karachi',
      },
      'saddar': {
        'name': 'Saddar',
        'lat': 24.8607,
        'lng': 67.0011,
        'subtitle': 'Commercial Area • Karachi',
      },
      'gulshan': {
        'name': 'Gulshan-e-Iqbal',
        'lat': 24.9333,
        'lng': 67.1167,
        'subtitle': 'Area • Karachi',
      },
      'nazimabad': {
        'name': 'Nazimabad',
        'lat': 24.9333,
        'lng': 67.1167,
        'subtitle': 'Area • Karachi',
      },
      'malir': {
        'name': 'Malir',
        'lat': 24.9333,
        'lng': 67.1167,
        'subtitle': 'Area • Karachi',
      },
      
      // Transportation
      'airport': {
        'name': 'Jinnah International Airport',
        'lat': 24.9065,
        'lng': 67.1606,
        'subtitle': 'Airport • Karachi',
      },
      'station': {
        'name': 'Karachi Cantt Station',
        'lat': 24.8607,
        'lng': 67.0011,
        'subtitle': 'Railway Station • Karachi',
      },
      
      // Hospitals
      'hospital': {
        'name': 'Aga Khan University Hospital',
        'lat': 24.8607,
        'lng': 67.0011,
        'subtitle': 'Hospital • Karachi',
      },
      'aga': {
        'name': 'Aga Khan University Hospital',
        'lat': 24.8607,
        'lng': 67.0011,
        'subtitle': 'Hospital • Karachi',
      },
      
      // BRT Stops
      'ftc': {
        'name': 'FTC',
        'lat': 24.8332,
        'lng': 67.0852,
        'subtitle': 'BRT Stop • Federal B Area',
      },
      'tower': {
        'name': 'Tower',
        'lat': 24.8132,
        'lng': 67.0152,
        'subtitle': 'BRT Stop • Saddar',
      },
      'karsaz': {
        'name': 'Karsaz',
        'lat': 24.8432,
        'lng': 67.1052,
        'subtitle': 'BRT Stop • Karsaz',
      },
      'metropole': {
        'name': 'Metropole',
        'lat': 24.8232,
        'lng': 67.0652,
        'subtitle': 'BRT Stop • Metropole',
      },
      'nipa': {
        'name': 'NIPA',
        'lat': 24.8232,
        'lng': 67.0652,
        'subtitle': 'BRT Stop • NIPA',
      },
      'gulshan': {
        'name': 'Gulshan-e-Iqbal',
        'lat': 24.9333,
        'lng': 67.1167,
        'subtitle': 'BRT Stop • Gulshan',
      },
    };
    
    // Check for matches
    for (final entry in commonLocations.entries) {
      String key = entry.key;
      String name = entry.value['name'].toString().toLowerCase();
      
      // Check if pattern matches the key or name
      if (key.contains(lowercasePattern) || 
          name.contains(lowercasePattern) ||
          // Special case for "fast uni" combination
          (lowercasePattern.contains('fast') && lowercasePattern.contains('uni') && 
           (key == 'fast' || key == 'uni'))) {
        suggestions.add(SearchResult(
          name: entry.value['name'],
          subtitle: entry.value['subtitle'],
          latitude: entry.value['lat'],
          longitude: entry.value['lng'],
          type: SearchResultType.generalLocation,
          location: entry.value,
        ));
      }
    }
    
    return suggestions.take(3).toList(); // Limit to 3 instant suggestions
  }

  void _showMapPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick Destination on Map'),
        content: const Text(
          'This feature would open an interactive map where you can '
          'tap to select your destination. For now, please use the '
          'search field above to find BRT stops.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearchesList() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: constraints.maxHeight,
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: _recentSearches.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final search = _recentSearches[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.shade200,
                    child: Icon(
                      Icons.history,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    search.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    search.subtitle,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                  onTap: () async {
                    setState(() {
                      _selectedDestination = SearchResult(
                        name: search.name,
                        subtitle: search.subtitle,
                        latitude: search.latitude,
                        longitude: search.longitude,
                        type: SearchResultType.generalLocation,
                        location: {
                          'name': search.name,
                          'latitude': search.latitude,
                          'longitude': search.longitude,
                        },
                      );
                      _controller.text = search.name;
                    });
                    // Update timestamp and save again
                    await _recentSearchesService.addRecentSearch(RecentSearch(
                      query: search.name,
                      name: search.name,
                      subtitle: search.subtitle,
                      latitude: search.latitude,
                      longitude: search.longitude,
                      timestamp: DateTime.now(),
                    ));
                    _navigateToRoute();
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _navigateToRoute() {
    print('_navigateToRoute called'); // Debug print
    if (_selectedDestination == null) {
      print('_selectedDestination is null'); // Debug print
      return;
    }

    final locationService = context.read<EnhancedLocationService>();
    if (locationService.currentPosition == null) {
      print('Location not available'); // Debug print
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for location to be detected first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print('Navigating directly to route details screen'); // Debug print
    // Navigate directly to route details screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RouteDetailsScreen(
          destinationLat: _selectedDestination!.latitude,
          destinationLng: _selectedDestination!.longitude,
          destinationName: _selectedDestination!.name,
        ),
      ),
    );
  }
}
