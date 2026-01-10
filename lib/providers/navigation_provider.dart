// providers/navigation_provider.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/navigation_service.dart';
import '../services/location_service.dart';

enum NavigationState {
  idle,
  searching,
  routesReady,
  navigating,
  arrived,
  error,
}

class NavigationProvider with ChangeNotifier {
  final NavigationService _navigationService = NavigationService();
  final LocationService _locationService = LocationService();

  NavigationState _state = NavigationState.idle;

  List<RouteOption> _routes = [];
  RouteOption? _selectedRoute;

  Position? _currentPosition;
  LatLng? _startLocation;
  LatLng? _endLocation;

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  double _progress = 0.0;
  double _remainingDistance = 0.0;
  Duration _eta = Duration.zero;

  String _errorMessage = '';
  String _selectedProfile = 'driving-car';

  // GETTERS
  NavigationState get state => _state;
  List<RouteOption> get routes => _routes;
  RouteOption? get selectedRoute => _selectedRoute;
  Set<Polyline> get polylines => _polylines;
  Set<Marker> get markers => _markers;

  double get progress => _progress;
  double get remainingDistance => _remainingDistance;
  Duration get eta => _eta;

  String get errorMessage => _errorMessage;
  String get selectedProfile => _selectedProfile;
  bool get isNavigating => _state == NavigationState.navigating;

  LatLng? get startLocation => _startLocation;
  LatLng? get endLocation => _endLocation;

  NavigationProvider() {
    _initializeLocation();
  }

  /// ---------------------------------------------------------
  /// INITIALIZE LOCATION STREAM
  /// ---------------------------------------------------------
  void _initializeLocation() {
    _locationService.positionStream.listen((position) {
      _currentPosition = position;

      if (_selectedRoute != null && isNavigating) {
        _updateNavigationProgress(position);
      }

      notifyListeners();
    });
  }

  /// ---------------------------------------------------------
  /// SET START LOCATION
  /// ---------------------------------------------------------
  void setStartLocation(LatLng location, {bool isCurrentLocation = false}) {
    _startLocation = location;

    _addMarker(
      location,
      "start",
      isCurrentLocation ? "Current Location" : "Start Location",
      BitmapDescriptor.defaultMarkerWithHue(
        isCurrentLocation
            ? BitmapDescriptor.hueGreen
            : BitmapDescriptor.hueBlue,
      ),
    );

    notifyListeners();
  }

  /// ---------------------------------------------------------
  /// SET END LOCATION
  /// ---------------------------------------------------------
  void setEndLocation(LatLng location) {
    _endLocation = location;

    _addMarker(
      location,
      "end",
      "Destination",
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );

    notifyListeners();
  }

  /// ---------------------------------------------------------
  /// MARKER HANDLING
  /// ---------------------------------------------------------
  void _addMarker(
    LatLng position,
    String id,
    String title,
    BitmapDescriptor icon,
  ) {
    _markers.removeWhere((m) => m.markerId.value == id);

    _markers.add(
      Marker(
        markerId: MarkerId(id),
        position: position,
        infoWindow: InfoWindow(title: title),
        icon: icon,
      ),
    );
  }

  /// ---------------------------------------------------------
  /// SEARCH ROUTES (OSRM + fallback)
  /// ---------------------------------------------------------
  Future<void> searchRoutes() async {
    if (_startLocation == null || _endLocation == null) {
      _setError("Please set both start and destination.");
      return;
    }

    final distance = NavigationService.calculateDistance(
      _startLocation!,
      _endLocation!,
    );

    if (distance < 10) {
      _setError("Start and end points are too close.");
      return;
    }

    _state = NavigationState.searching;
    _errorMessage = "";
    _routes.clear();
    _polylines.clear();
    _selectedRoute = null;
    notifyListeners();

    try {
      final response = await _navigationService.getRoutes(
        start: _startLocation!,
        end: _endLocation!,
        profile: _selectedProfile,
      );

      if (response == null || response.routes.isEmpty) {
        _setError("No routes found. Try another location.");
        return;
      }

      _routes = response.routes;

      _generateRoutePolylines();

      _state = NavigationState.routesReady;

      // AUTO-SELECT FASTEST ROUTE
      selectRoute(_routes.first);
    } catch (e) {
      _setError(e.toString().replaceAll("Exception: ", ""));
    }

    notifyListeners();
  }

  /// ---------------------------------------------------------
  /// DRAW POLYLINES FOR ALL ROUTES
  /// ---------------------------------------------------------
  void _generateRoutePolylines() {
    _polylines.clear();

    for (int i = 0; i < _routes.length; i++) {
      final r = _routes[i];
      final color = NavigationService.getRouteColor(i);

      _polylines.add(
        Polyline(
          polylineId: PolylineId(r.id),
          points: r.points,
          width: 6,
          color: Color(color),
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }
  }

  /// ---------------------------------------------------------
  /// SELECT ROUTE TO NAVIGATE
  /// ---------------------------------------------------------
  void selectRoute(RouteOption route) {
    _selectedRoute = route;

    _polylines = _polylines.map((polyline) {
      final isSelected = polyline.polylineId.value == route.id;
      final idx = _routes.indexWhere((r) => r.id == route.id);
      final c = NavigationService.getRouteColor(idx);

      return polyline.copyWith(
        widthParam: isSelected ? 8 : 6,
        colorParam: isSelected
            ? Color(c).withOpacity(0.9)
            : Color(c).withOpacity(0.6),
      );
    }).toSet();

    notifyListeners();
  }

  /// ---------------------------------------------------------
  /// START NAVIGATION
  /// ---------------------------------------------------------
  void startNavigation() {
    if (_selectedRoute == null) {
      _setError("No route selected.");
      return;
    }

    _state = NavigationState.navigating;
    _locationService.startUltraFastTracking();

    if (_currentPosition != null) {
      _updateNavigationProgress(_currentPosition!);
    }

    notifyListeners();
  }

  /// ---------------------------------------------------------
  /// UPDATE NAVIGATION PROGRESS
  /// ---------------------------------------------------------
  void _updateNavigationProgress(Position pos) {
    if (_selectedRoute == null) return;

    final latLng = LatLng(pos.latitude, pos.longitude);

    _progress = NavigationService.calculateRouteProgress(
      _selectedRoute!.points,
      latLng,
    );

    _remainingDistance = NavigationService.calculateRemainingDistance(
      _selectedRoute!.points,
      latLng,
    );

    _eta = NavigationService.calculateETA(_remainingDistance, pos.speed);

    final distanceToEnd = NavigationService.calculateDistance(
      latLng,
      _selectedRoute!.end,
    );

    if (distanceToEnd < 50) {
      _state = NavigationState.arrived;
      _locationService.stopTracking();
      _setError("You have arrived.");
    }

    notifyListeners();
  }

  /// ---------------------------------------------------------
  /// STOP NAVIGATION
  /// ---------------------------------------------------------
  void stopNavigation() {
    _state = NavigationState.routesReady;
    _locationService.stopTracking();

    _progress = 0;
    _remainingDistance = 0;
    _eta = Duration.zero;

    notifyListeners();
  }

  /// ---------------------------------------------------------
  /// SET PROFILE (Car/Bike/Walk)
  /// ---------------------------------------------------------
  void setProfile(String profile) {
    _selectedProfile = profile;
    notifyListeners();
  }

  /// ---------------------------------------------------------
  /// ERROR HANDLING
  /// ---------------------------------------------------------
  void _setError(String msg) {
    _errorMessage = msg;
    _state = NavigationState.error;
    notifyListeners();
  }

  /// ---------------------------------------------------------
  /// CLEAR EVERYTHING
  /// ---------------------------------------------------------
  void clear() {
    _state = NavigationState.idle;
    _routes.clear();
    _polylines.clear();
    _markers.clear();
    _selectedRoute = null;
    _errorMessage = "";
    _startLocation = null;
    _endLocation = null;

    _progress = 0;
    _remainingDistance = 0;
    _eta = Duration.zero;

    notifyListeners();
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }
}
