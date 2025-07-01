import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../services/location_service.dart';
import '../services/geocoding_service.dart';
import '../models/stop.dart';
import '../screens/map_screen.dart';

class SearchResult {
  final String name;
  final String subtitle;
  final double latitude;
  final double longitude;
  final SearchResultType type;
  final Stop? stop; // Only for BRT stops
  final LocationResult? location; // Only for general locations

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

  factory SearchResult.fromLocation(LocationResult location) {
    return SearchResult(
      name: location.displayName,
      subtitle: '${location.type} • ${location.address}',
      latitude: location.latitude,
      longitude: location.longitude,
      type: SearchResultType.generalLocation,
      location: location,
    );
  }
}

enum SearchResultType { brtStop, generalLocation }

class DestinationSearch extends StatefulWidget {
  const DestinationSearch({super.key});

  @override
  State<DestinationSearch> createState() => _DestinationSearchState();
}

class _DestinationSearchState extends State<DestinationSearch> {
  final TextEditingController _controller = TextEditingController();
  SearchResult? _selectedDestination;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TypeAheadField<SearchResult>(
          controller: _controller,
          builder: (context, controller, focusNode) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Search anywhere in Karachi (places, BRT stops, areas)...',
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
            if (pattern.isEmpty) return [];
            
            final List<SearchResult> results = [];
            
            // Search BRT stops first
            final dataService = context.read<DataService>();
            await dataService.loadBRTData();
            final brtStops = dataService.searchStops(pattern);
            results.addAll(brtStops.map((stop) => SearchResult.fromStop(stop)));
            
            // Search general Karachi locations
            final locations = await GeocodingService.searchPlaces(pattern);
            results.addAll(locations.map((location) => SearchResult.fromLocation(location)));
            
            return results;
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
          onSelected: (SearchResult suggestion) {
            setState(() {
              _selectedDestination = suggestion;
              _controller.text = suggestion.name;
            });
          },
          emptyBuilder: (context) => const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No results found.\nTry searching for places, areas, or BRT stops in Karachi.',
              textAlign: TextAlign.center,
            ),
          ),
          loadingBuilder: (context) => const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(),
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
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _selectedDestination != null ? () => _navigateToRoute() : null,
                icon: const Icon(Icons.directions),
                label: const Text('Get Directions'),
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
      ],
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
        Consumer<DataService>(
          builder: (context, dataService, child) {
            // Show popular stops (first few stops as example)
            final popularStops = dataService.stops.take(6).toList();
            
            if (popularStops.isEmpty) {
              return const SizedBox();
            }

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: popularStops.map((stop) {
                return ActionChip(
                  avatar: Icon(
                    Icons.place,
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
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
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

  void _navigateToRoute() {
    if (_selectedDestination == null) return;

    final locationService = context.read<LocationService>();
    if (locationService.currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for location to be detected first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MapScreen(
          destinationLat: _selectedDestination!.latitude,
          destinationLng: _selectedDestination!.longitude,
          destinationName: _selectedDestination!.name,
        ),
      ),
    );
  }
}
