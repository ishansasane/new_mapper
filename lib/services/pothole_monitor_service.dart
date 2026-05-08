import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:new_mapper/classes/pothole_data.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PotholeMonitorService {
  static final PotholeMonitorService _instance =
      PotholeMonitorService._internal();
  factory PotholeMonitorService() => _instance;
  PotholeMonitorService._internal();

  StreamSubscription<UserAccelerometerEvent>? _userAccelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<Position>? _positionSubscription;

  List<PotholeData> _detectedPotholes = [];
  bool _isMonitoring = false;

  // Threshold values for pothole detection
  static const double ACCELERATION_THRESHOLD = 2.5;
  static const double GYROSCOPE_THRESHOLD = 1.8;

  final StreamController<List<PotholeData>> _potholesStreamController =
      StreamController<List<PotholeData>>.broadcast();

  Stream<List<PotholeData>> get potholesStream =>
      _potholesStreamController.stream;

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _detectedPotholes.clear();

    // Try to get initial position immediately
    try {
      _currentPosition = await Geolocator.getLastKnownPosition();
      Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 5),
      ).then((Position position) {
        _currentPosition = position;
      }).catchError((_) {
        // Ignore timeout
      });
    } catch (e) {
      print("Error getting initial position: $e");
    }

    // Start location updates
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 1, // 1 meter
          ),
        ).listen((Position position) {
          _currentPosition = position;
        });

    // Start accelerometer monitoring (using user accelerometer to exclude gravity)
    _userAccelerometerSubscription = userAccelerometerEventStream().listen((
      UserAccelerometerEvent event,
    ) {
      _handleSensorData(event.x, event.y, event.z, 'accelerometer');
    });

    // Start gyroscope monitoring
    _gyroscopeSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      _handleSensorData(event.x, event.y, event.z, 'gyroscope');
    });
  }

  Position? _currentPosition;
  double _lastAcceleration = 0.0;
  double _lastGyroscope = 0.0;

  void _handleSensorData(double x, double y, double z, String sensorType) {
    if (!_isMonitoring) return;

    double magnitude = sqrt(x * x + y * y + z * z);

    if (sensorType == 'accelerometer') {
      _lastAcceleration = magnitude;
    } else {
      _lastGyroscope = magnitude;
    }

    // Detect pothole based on threshold values
    if (_lastAcceleration > ACCELERATION_THRESHOLD &&
        _lastGyroscope > GYROSCOPE_THRESHOLD) {
      
      // Calculate severity based on sensor values
      double severity =
          ((_lastAcceleration - ACCELERATION_THRESHOLD) +
              (_lastGyroscope - GYROSCOPE_THRESHOLD)) /
          2;

      final pothole = PotholeData(
        // Use 0.0 as fallback if GPS hasn't locked yet, so shaking works indoors
        latitude: _currentPosition?.latitude ?? 0.0,
        longitude: _currentPosition?.longitude ?? 0.0,
        acceleration: _lastAcceleration,
        gyroscope: _lastGyroscope,
        timestamp: DateTime.now(),
        severity: severity,
      );

      _addPothole(pothole);
    }
  }

  void _addPothole(PotholeData pothole) {
    // Avoid duplicate detections within 2 seconds and 5 meters
    final recentPothole = _detectedPotholes.firstWhere(
      (existing) =>
          pothole.timestamp.difference(existing.timestamp).inSeconds < 2 &&
          _calculateDistance(
                pothole.latitude,
                pothole.longitude,
                existing.latitude,
                existing.longitude,
              ) <
              5,
      orElse: () => PotholeData(
        latitude: 0,
        longitude: 0,
        acceleration: 0,
        gyroscope: 0,
        timestamp: DateTime.now(),
        severity: 0,
      ),
    );

    // If recentPothole.severity == 0, it means the orElse was returned, so it's a new pothole
    if (recentPothole.severity == 0) {
      _detectedPotholes.add(pothole);
      _potholesStreamController.add(List.from(_detectedPotholes));
      _savePotholesToStorage();
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Avoid calculation if both points are dummy (0,0)
    if (lat1 == 0 && lon1 == 0 && lat2 == 0 && lon2 == 0) return 0;
    
    const double earthRadius = 6371000; // meters
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  Future<void> stopMonitoring() async {
    _isMonitoring = false;

    await _userAccelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    await _positionSubscription?.cancel();

    _userAccelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _positionSubscription = null;

    await _savePotholesToStorage();
  }

  Future<void> _savePotholesToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final potholesJson = _detectedPotholes.map((p) => p.toJson()).toList();
    prefs.setString('detected_potholes', json.encode(potholesJson));
  }

  Future<void> loadPotholesFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final potholesJson = prefs.getString('detected_potholes');

    if (potholesJson != null) {
      final List<dynamic> decoded = json.decode(potholesJson);
      _detectedPotholes = decoded
          .map((json) => PotholeData.fromJson(json))
          .toList();
      _potholesStreamController.add(List.from(_detectedPotholes));
    }
  }

  List<PotholeData> getDetectedPotholes() => List.from(_detectedPotholes);

  void clearPotholes() {
    _detectedPotholes.clear();
    _potholesStreamController.add([]);
    _clearStorage();
  }

  Future<void> _clearStorage() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('detected_potholes');
  }

  bool get isMonitoring => _isMonitoring;

  void dispose() {
    _userAccelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _positionSubscription?.cancel();
    _potholesStreamController.close();
  }
}
