// services/location_service.dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();
  final StreamController<bool> _trackingStatusController =
      StreamController<bool>.broadcast();

  Stream<Position> get positionStream => _positionController.stream;
  Stream<bool> get trackingStatusStream => _trackingStatusController.stream;

  Position? _lastPosition;
  bool _isTracking = false;
  StreamSubscription<Position>? _positionSubscription;

  Future<bool> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await _checkPermissions();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  // Ultra-fast location updates for navigation
  Future<void> startUltraFastTracking() async {
    if (_isTracking) return;

    try {
      bool hasPermission = await _checkPermissions();
      if (!hasPermission) return;

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      );

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) {
              _lastPosition = position;
              _positionController.add(position);
            },
            onError: (error) {
              print('Location stream error: $error');
            },
            cancelOnError: false,
          );

      _isTracking = true;
      _trackingStatusController.add(true);
    } catch (e) {
      print('Error starting live location: $e');
    }
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _isTracking = false;
    _trackingStatusController.add(false);
  }

  bool get isTracking => _isTracking;
  Position? get lastPosition => _lastPosition;

  void dispose() {
    stopTracking();
    _positionController.close();
    _trackingStatusController.close();
  }

  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}
