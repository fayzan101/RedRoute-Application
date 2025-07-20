import 'stop.dart';

class BusRoute {
  final String name;
  final List<Stop> stops;
  final String color;

  BusRoute({
    required this.name,
    required this.stops,
    this.color = '#E53E3E',
  });

  @override
  String toString() {
    return 'BusRoute{name: $name, stops: ${stops.length}, color: $color}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BusRoute && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}

class Journey {
  final Stop startStop;
  final Stop endStop;
  final List<BusRoute> routes;
  final Stop? transferStop;
  final double totalDistance;
  final String instructions;
  final double walkingDistanceToStart;
  final double walkingDistanceFromEnd;
  final double busDistance;

  Journey({
    required this.startStop,
    required this.endStop,
    required this.routes,
    this.transferStop,
    required this.totalDistance,
    required this.instructions,
    required this.walkingDistanceToStart,
    required this.walkingDistanceFromEnd,
    required this.busDistance,
  });

  bool get requiresTransfer => transferStop != null;

  String get transportSuggestionToStart {
    if (walkingDistanceToStart < 500) {
      return 'Walk (${(walkingDistanceToStart).round()}m)';
    } else if (walkingDistanceToStart < 2000) {
      return 'Rickshaw (${(walkingDistanceToStart / 1000).toStringAsFixed(1)}km)';
    } else {
      return 'Bykea/Careem (${(walkingDistanceToStart / 1000).toStringAsFixed(1)}km)';
    }
  }

  String get transportSuggestionFromEnd {
    if (walkingDistanceFromEnd < 500) {
      return 'Walk (${(walkingDistanceFromEnd).round()}m)';
    } else if (walkingDistanceFromEnd < 2000) {
      return 'Rickshaw (${(walkingDistanceFromEnd / 1000).toStringAsFixed(1)}km)';
    } else {
      return 'Bykea/Careem (${(walkingDistanceFromEnd / 1000).toStringAsFixed(1)}km)';
    }
  }
}
