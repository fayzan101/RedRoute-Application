import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../services/location_service.dart';
import '../models/stop.dart';
import '../screens/map_screen.dart';

class DestinationSearch extends StatefulWidget {
  const DestinationSearch({super.key});

  @override
  State<DestinationSearch> createState() => _DestinationSearchState();
}

class _DestinationSearchState extends State<DestinationSearch> {
  final TextEditingController _controller = TextEditingController();
  Stop? _selectedStop;

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
        TypeAheadField<Stop>(
          controller: _controller,
          builder: (context, controller, focusNode) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Search for a destination or BRT stop...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _selectedStop = null;
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
            
            final dataService = context.read<DataService>();
            await dataService.loadBRTData();
            return dataService.searchStops(pattern);
          },
          itemBuilder: (context, Stop suggestion) {
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: const Icon(
                  Icons.directions_bus,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Text(suggestion.name),
              subtitle: Text(
                'Routes: ${suggestion.routes.join(", ")}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            );
          },
          onSelected: (Stop suggestion) {
            setState(() {
              _selectedStop = suggestion;
              _controller.text = suggestion.name;
            });
          },
          emptyBuilder: (context) => const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No BRT stops found.\nTry searching for major landmarks or areas.',
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
                onPressed: _selectedStop != null ? () => _navigateToRoute() : null,
                icon: const Icon(Icons.directions),
                label: const Text('Get Directions'),
              ),
            ),
          ],
        ),
        
        // Selected destination info
        if (_selectedStop != null) ...[
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
    if (_selectedStop == null) return const SizedBox();

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
              _selectedStop!.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Available routes: ${_selectedStop!.routes.join(", ")}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
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
                      _selectedStop = stop;
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
    if (_selectedStop == null) return;

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
          destinationLat: _selectedStop!.lat,
          destinationLng: _selectedStop!.lng,
          destinationName: _selectedStop!.name,
        ),
      ),
    );
  }
}
