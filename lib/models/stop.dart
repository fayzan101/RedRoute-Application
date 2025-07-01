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
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      routes: List<String>.from(json['routes'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lng': lng,
      'routes': routes,
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
