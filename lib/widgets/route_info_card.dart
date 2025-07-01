import 'package:flutter/material.dart';
import '../models/route.dart';
import '../utils/distance_calculator.dart';

class RouteInfoCard extends StatelessWidget {
  final Journey journey;

  const RouteInfoCard({
    super.key,
    required this.journey,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.directions,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Journey Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (journey.requiresTransfer)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Transfer',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Route summary
            _buildRouteSummary(context),
            
            const SizedBox(height: 16),
            
            // Step-by-step instructions
            _buildInstructions(context),
            
            const SizedBox(height: 16),
            
            // Travel times and suggestions
            _buildTravelSuggestions(context),
            
            const SizedBox(height: 16),
            
            // Action buttons
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSummary(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  journey.startStop.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          
          if (journey.requiresTransfer && journey.transferStop != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 28),
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz, color: Colors.orange.shade600, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Transfer at ${journey.transferStop!.name}',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.place, color: Colors.red.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  journey.endStop.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                icon: Icons.straighten,
                label: 'Distance',
                value: DistanceCalculator.formatDistance(journey.totalDistance),
                color: Colors.blue.shade700,
              ),
              _buildSummaryItem(
                icon: Icons.access_time,
                label: 'Est. Time',
                value: '${_calculateTotalTime()}min',
                color: Colors.green.shade700,
              ),
              _buildSummaryItem(
                icon: Icons.directions_bus,
                label: 'Routes',
                value: journey.routes.length.toString(),
                color: Colors.purple.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step-by-step Directions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            journey.instructions,
            style: const TextStyle(height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildTravelSuggestions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Travel Suggestions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSuggestionCard(
                title: 'To Bus Stop',
                suggestion: journey.transportSuggestionToStart,
                icon: _getTransportIcon(journey.walkingDistanceToStart),
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSuggestionCard(
                title: 'From Bus Stop',
                suggestion: journey.transportSuggestionFromEnd,
                icon: _getTransportIcon(journey.walkingDistanceFromEnd),
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuggestionCard({
    required String title,
    required String suggestion,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            suggestion,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              _showRouteDetails(context);
            },
            icon: const Icon(Icons.info_outline),
            label: const Text('More Details'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              _launchNavigation(context);
            },
            icon: const Icon(Icons.navigation),
            label: const Text('Start Journey'),
          ),
        ),
      ],
    );
  }

  IconData _getTransportIcon(double distance) {
    if (distance < 500) {
      return Icons.directions_walk;
    } else if (distance < 2000) {
      return Icons.directions_car;
    } else {
      return Icons.local_taxi;
    }
  }

  int _calculateTotalTime() {
    final walkingTime1 = DistanceCalculator.calculateWalkingTimeMinutes(journey.walkingDistanceToStart);
    final walkingTime2 = DistanceCalculator.calculateWalkingTimeMinutes(journey.walkingDistanceFromEnd);
    final busDistance = journey.totalDistance - journey.walkingDistanceToStart - journey.walkingDistanceFromEnd;
    final busTime = DistanceCalculator.calculateBusTimeMinutes(busDistance);
    
    return walkingTime1 + walkingTime2 + busTime + (journey.requiresTransfer ? 5 : 0); // Add 5 min for transfer
  }

  void _showRouteDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Route Details',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildDetailSection('Boarding Stop', journey.startStop.name),
                    _buildDetailSection('Destination Stop', journey.endStop.name),
                    _buildDetailSection('Total Distance', DistanceCalculator.formatDistance(journey.totalDistance)),
                    _buildDetailSection('Estimated Time', '${_calculateTotalTime()} minutes'),
                    if (journey.requiresTransfer && journey.transferStop != null)
                      _buildDetailSection('Transfer Stop', journey.transferStop!.name),
                    _buildDetailSection('Available Routes', journey.routes.map((r) => r.name).join(', ')),
                    const SizedBox(height: 16),
                    Text(
                      'Detailed Instructions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(journey.instructions),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$title:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(content)),
        ],
      ),
    );
  }

  void _launchNavigation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Navigation'),
        content: const Text(
          'This would typically open your preferred navigation app '
          'with turn-by-turn directions to the boarding stop. For now, '
          'please follow the step-by-step instructions provided.',
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
}
