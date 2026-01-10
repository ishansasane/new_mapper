import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:new_mapper/services/location_service.dart';

class MapProvider with ChangeNotifier {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isTracking = false;
  final Set<Marker> _markers = {};

  GoogleMapController? get mapController => _mapController;
  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  bool get isTracking => _isTracking;
  Set<Marker> get markers => _markers;

  final LatLng _initialPosition = const LatLng(19.9975, 73.7898);
  LatLng get initialPosition => _initialPosition;

  final LocationService _locationService = LocationService();

  MapProvider() {
    _initializeLocation();
  }

  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    notifyListeners();
  }

  void _initializeLocation() async {
    // Start ultra-fast tracking immediately
    await _locationService.startUltraFastTracking();

    // Listen to location updates
    _locationService.positionStream.listen((position) {
      _updatePosition(position);
    });

    // Listen to tracking status
    _locationService.trackingStatusStream.listen((isTracking) {
      _isTracking = isTracking;
      notifyListeners();
    });
  }

  void _updatePosition(Position position) {
    _currentPosition = position;
    _isLoading = false;

    // Add marker for current position
    _updateMarker();

    // Move camera to follow position (smooth animation)
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
    );

    notifyListeners();
  }

  void _updateMarker() {
    if (_currentPosition != null) {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Current Location'),
          rotation: _currentPosition!.heading, // Show direction if available
        ),
      );
    }
    notifyListeners();
  }

  Future<void> centerToCurrentLocation() async {
    if (_currentPosition != null) {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        ),
      );
    } else {
      // Get current location if not available
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        _updatePosition(position);
      }
    }
  }

  void toggleTracking() {
    if (_isTracking) {
      _locationService.stopTracking();
    } else {
      _locationService.startUltraFastTracking();
    }
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }
}
