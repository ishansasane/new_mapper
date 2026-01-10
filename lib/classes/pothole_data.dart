class PotholeData {
  final double latitude;
  final double longitude;
  final double acceleration;
  final double gyroscope;
  final DateTime timestamp;
  final double severity;

  PotholeData({
    required this.latitude,
    required this.longitude,
    required this.acceleration,
    required this.gyroscope,
    required this.timestamp,
    required this.severity,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'acceleration': acceleration,
      'gyroscope': gyroscope,
      'timestamp': timestamp.toIso8601String(),
      'severity': severity,
    };
  }

  factory PotholeData.fromJson(Map<String, dynamic> json) {
    return PotholeData(
      latitude: json['latitude'],
      longitude: json['longitude'],
      acceleration: json['acceleration'],
      gyroscope: json['gyroscope'],
      timestamp: DateTime.parse(json['timestamp']),
      severity: json['severity'],
    );
  }
}
