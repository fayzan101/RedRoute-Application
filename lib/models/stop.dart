class Stop {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final List<String> routes;

  Stop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.routes,
  });

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      id: json['stopId'] as String,
      name: json['name'] as String,
      lat: (json['latitude'] as num).toDouble(),
      lng: (json['longitude'] as num).toDouble(),
      routes: List<String>.from(json['availableRoutes'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stopId': id,
      'name': name,
      'latitude': lat,
      'longitude': lng,
      'availableRoutes': routes,
    };
  }

  @override
  String toString() {
    return 'Stop{id: $id, name: $name, lat: $lat, lng: $lng, routes: $routes}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Stop && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
