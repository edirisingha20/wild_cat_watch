class Alert {
  const Alert({
    required this.id,
    required this.description,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.image,
    required this.createdAt,
  });

  final int id;
  final String description;
  final String locationName;
  final double latitude;
  final double longitude;
  final String? image;
  final DateTime createdAt;

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] as int,
      description: json['description'] as String,
      locationName: json['location_name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      image: json['image'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
