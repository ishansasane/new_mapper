// services/navigation_service.dart
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'package:geolocator/geolocator.dart';

class NavigationService {
  // Route colors for different options
  static const List<int> _routeColors = [
    0xFFE74C3C, // Red
    0xFF2ECC71, // Green
    0xFF3498DB, // Blue
    0xFFF39C12, // Orange
    0xFF9B59B6, // Purple
  ];

  Future<NavigationResponse?> getRoutes({
    required LatLng start,
    required LatLng end,
    required String profile,
  }) async {
    try {
      print(
        '🔍 Fetching routes from OSRM: ${start.latitude},${start.longitude} to ${end.latitude},${end.longitude}',
      );

      // Convert profile to OSRM format
      final osrmProfile = _convertProfileToOSRM(profile);

      final startCoords = '${start.longitude},${start.latitude}';
      final endCoords = '${end.longitude},${end.latitude}';

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/$osrmProfile/$startCoords;$endCoords?overview=full&geometries=geojson&alternatives=true&steps=true',
      );

      print('🌐 OSRM URL: $url');

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      print('📨 OSRM Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return NavigationResponse.fromJson(data, start, end);
      } else {
        print('❌ OSRM Error ${response.statusCode}: ${response.body}');
        throw Exception('Failed to fetch routes from routing service');
      }
    } catch (e) {
      print('💥 Navigation service error: $e');

      if (e.toString().contains('Failed host lookup')) {
        throw Exception('No internet connection. Please check your network.');
      } else if (e.toString().contains('Timeout')) {
        throw Exception('Request timeout. Please try again.');
      } else {
        throw Exception(
          'Failed to find route: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  String _convertProfileToOSRM(String profile) {
    switch (profile) {
      case 'driving-car':
        return 'driving';
      case 'cycling-regular':
        return 'cycling';
      case 'foot-walking':
        return 'walking';
      default:
        return 'driving';
    }
  }

  static int getRouteColor(int index) {
    return _routeColors[index % _routeColors.length];
  }

  // Calculate distance between two points
  static double calculateDistance(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  // Create straight line route as fallback
  static List<LatLng> createStraightLineRoute(LatLng start, LatLng end) {
    final distance = calculateDistance(start, end);
    final numPoints = (distance * 10).ceil().clamp(10, 100);
    final routePoints = <LatLng>[];

    for (int i = 0; i <= numPoints; i++) {
      final ratio = i / numPoints;
      final lat = start.latitude + (end.latitude - start.latitude) * ratio;
      final lng = start.longitude + (end.longitude - start.longitude) * ratio;
      routePoints.add(LatLng(lat, lng));
    }

    return routePoints;
  }

  // Find nearest point on route to current position
  static int findNearestPointIndex(List<LatLng> route, LatLng currentPosition) {
    if (route.isEmpty) return 0;

    int nearestIndex = 0;
    double minDistance = double.maxFinite;

    for (int i = 0; i < route.length; i++) {
      final distance = calculateDistance(route[i], currentPosition);
      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }

    return nearestIndex;
  }

  // Calculate progress along route
  static double calculateRouteProgress(
    List<LatLng> route,
    LatLng currentPosition,
  ) {
    if (route.isEmpty) return 0.0;

    final nearestIndex = findNearestPointIndex(route, currentPosition);
    return (nearestIndex / route.length).clamp(0.0, 1.0);
  }

  // Calculate remaining distance
  static double calculateRemainingDistance(
    List<LatLng> route,
    LatLng currentPosition,
  ) {
    if (route.isEmpty) return 0.0;

    final nearestIndex = findNearestPointIndex(route, currentPosition);
    double remainingDistance = 0;

    for (int i = nearestIndex; i < route.length - 1; i++) {
      remainingDistance += calculateDistance(route[i], route[i + 1]);
    }

    return remainingDistance;
  }

  // Calculate ETA
  static Duration calculateETA(double distance, double speed) {
    if (speed <= 0) speed = 30.0; // Default to 30 km/h if speed not available
    final hours = distance / (speed * 1000);
    final totalMinutes = (hours * 60).toInt();
    return Duration(minutes: totalMinutes.clamp(1, 24 * 60));
  }
}

class NavigationResponse {
  final List<RouteOption> routes;
  final LatLng start;
  final LatLng end;

  NavigationResponse({
    required this.routes,
    required this.start,
    required this.end,
  });

  factory NavigationResponse.fromJson(
    Map<String, dynamic> json,
    LatLng start,
    LatLng end,
  ) {
    print('📊 Parsing OSRM route response...');

    final routes = <RouteOption>[];

    if (json['code'] == 'Ok' && json['routes'] != null) {
      final routeData = json['routes'] as List;
      print('📈 Found ${routeData.length} route alternatives');

      for (int i = 0; i < routeData.length; i++) {
        try {
          final route = routeData[i] as Map<String, dynamic>;
          final routeOption = RouteOption.fromJson(route, start, end, i);

          // Ensure the route starts from the exact start location
          if (routeOption.points.isNotEmpty) {
            // Replace the first point with the exact start location to ensure accuracy
            routeOption.points[0] = start;
          }

          routes.add(routeOption);
          print(
            '🛣️ Route $i: ${routeOption.summary} - ${routeOption.points.length} points',
          );
        } catch (e) {
          print('⚠️ Error parsing route $i: $e');
        }
      }
    }

    // If no routes found, create straight line route
    if (routes.isEmpty) {
      print('🔄 Creating straight line route as fallback');
      final straightRoute = NavigationService.createStraightLineRoute(
        start,
        end,
      );

      // Ensure the route starts from exact start location
      if (straightRoute.isNotEmpty) {
        straightRoute[0] = start;
      }

      final distance = NavigationService.calculateDistance(start, end);
      final duration = (distance * 2).toInt(); // Estimate 2 min per km

      routes.add(
        RouteOption(
          id: 'route_fallback_${DateTime.now().millisecondsSinceEpoch}',
          points: straightRoute,
          distance: distance,
          duration: duration.toDouble(),
          summary:
              '${(distance / 1000).toStringAsFixed(2)} km • ${(duration / 60).ceil()} min',
          start: start,
          end: end,
        ),
      );
    }

    // Sort routes by duration
    routes.sort((a, b) => a.duration.compareTo(b.duration));

    print('✅ Successfully parsed ${routes.length} routes');
    return NavigationResponse(routes: routes, start: start, end: end);
  }
}

class RouteOption {
  final String id;
  final List<LatLng> points;
  final double distance;
  final double duration;
  final String summary;
  final LatLng start;
  final LatLng end;

  RouteOption({
    required this.id,
    required this.points,
    required this.distance,
    required this.duration,
    required this.summary,
    required this.start,
    required this.end,
  });

  factory RouteOption.fromJson(
    Map<String, dynamic> json,
    LatLng start,
    LatLng end,
    int index,
  ) {
    final geometry = json['geometry'] as Map<String, dynamic>? ?? {};
    final distanceMeters = (json['distance'] as num? ?? 0).toDouble();
    final durationSeconds = (json['duration'] as num? ?? 0).toDouble();

    List<LatLng> points = [];

    // Decode OSRM geometry
    final coords = geometry['coordinates'] as List?;
    if (coords != null && geometry['type'] == 'LineString') {
      points = coords.map<LatLng>((coord) {
        return LatLng(coord[1], coord[0]); // OSRM uses [lon, lat]
      }).toList();
    }

    // 🔥 FIX 1: Insert exact START location at the beginning
    if (points.isNotEmpty) {
      points.insert(0, start);
    } else {
      points = [start];
    }

    // 🔥 FIX 2: Insert exact END location at end
    points.add(end);

    return RouteOption(
      id: 'route_${DateTime.now().millisecondsSinceEpoch}_$index',
      points: points,
      distance: distanceMeters,
      duration: durationSeconds,
      summary:
          '${(distanceMeters / 1000).toStringAsFixed(2)} km • ${_formatDuration(durationSeconds)}',
      start: start,
      end: end,
    );
  }

  static String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '<1m';
    }
  }
}
