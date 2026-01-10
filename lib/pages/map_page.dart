// pages/map_page.dart
import 'package:flutter/material.dart';

import 'package:new_mapper/pages/location_selection_page.dart';
import 'package:new_mapper/services/navigation_service.dart';
import 'package:new_mapper/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/navigation_provider.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final supabase = Supabase.instance.client;

  Set<Marker> _potholeMarkers = {};
  final Set<String> _alertedPotholes = {};

  bool _potholesLoaded = false;
  Set<Circle> _potholeCircles = {};

  GoogleMapController? _mapController;
  bool _isMapReady = false;
  bool _showRoutePanel = false;
  bool _showSearchPanel = true;
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  Color _getSeverityColor(double severity) {
    if (severity <= 10) {
      return const Color(0xFFB9F6CA); // very light green
    } else if (severity <= 30) {
      return const Color(0xFF00C853); // green
    } else if (severity <= 50) {
      return const Color(0xFFFFEB3B); // yellow
    } else if (severity <= 70) {
      return const Color(0xFFFF9800); // orange
    } else if (severity <= 90) {
      return const Color(0xFFD50000); // red
    } else {
      return const Color(0xFF6A1B9A); // purple
    }
  }

  void _checkNearbyPotholes(Position userPosition) {
    for (final circle in _potholeCircles) {
      final distance = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        circle.center.latitude,
        circle.center.longitude,
      );

      // Trigger alert if within 50 meters
      if (distance <= 50) {
        final potholeId = circle.circleId.value;

        if (!_alertedPotholes.contains(potholeId)) {
          _alertedPotholes.add(potholeId);

          NotificationService.showPotholeWarning(
            _getSeverityFromColor(circle.fillColor),
          );
        }
      }
    }
  }

  double _getSeverityFromColor(Color color) {
    if (color == Colors.green || color == Colors.lightGreen) return 20;
    if (color == Colors.yellow) return 40;
    if (color == Colors.orange) return 65;
    if (color == Colors.red) return 85;
    return 95;
  }

  Future<void> _loadPotholesFromSupabase() async {
    try {
      final response = await supabase
          .from('potholes')
          .select('latitude, longitude, severity');

      final Set<Circle> circles = {};

      for (int i = 0; i < response.length; i++) {
        final p = response[i];
        final severity = (p['severity'] as num).toDouble();

        circles.add(
          Circle(
            circleId: CircleId('pothole_$i'),
            center: LatLng(p['latitude'], p['longitude']),
            radius: 18, // 🔵 DOT SIZE (meters)
            fillColor: _getSeverityColor(severity).withOpacity(0.8),
            strokeColor: Colors.transparent,
          ),
        );
      }

      setState(() {
        _potholeCircles = circles;
        _potholesLoaded = true;
      });
    } catch (e) {
      debugPrint('Error loading potholes: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _isMapReady = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerToMyLocation();
    });

    if (!_potholesLoaded) {
      _loadPotholesFromSupabase();
    }
  }

  void _toggleRoutePanel() {
    setState(() {
      _showRoutePanel = !_showRoutePanel;
    });
  }

  void _toggleSearchPanel() {
    setState(() {
      _showSearchPanel = !_showSearchPanel;
    });
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<NavigationProvider>(
        builder: (context, navigationProvider, child) {
          // Update text controllers when locations change
          if (navigationProvider.startLocation != null &&
              _startController.text.isEmpty) {
            _startController.text = "Current Location";
          }

          return Stack(
            children: [
              GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: const CameraPosition(
                  target: LatLng(19.9975, 73.7898),
                  zoom: 14.0,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                polylines: navigationProvider.polylines,
                markers: navigationProvider.markers,
                circles: _potholeCircles,

                compassEnabled: true,
                rotateGesturesEnabled: true,
                onTap: (latLng) => _onMapTap(latLng, navigationProvider),
              ),
              // FloatingActionButton(
              //   onPressed: () {
              //     NotificationService.showPotholeWarning(75);
              //   },
              //   heroTag: 'test_notification',
              //   mini: true,
              //   backgroundColor: Colors.purple,
              //   child: const Icon(Icons.notifications),
              // ),

              // const SizedBox(height: 8),

              // Floating Search Panel
              if (_showSearchPanel && !navigationProvider.isNavigating)
                _buildSearchPanel(navigationProvider),

              // Floating Route Selection Panel
              if (_showRoutePanel &&
                  navigationProvider.state == NavigationState.routesReady)
                _buildRouteSelectionPanel(navigationProvider),

              if (navigationProvider.isNavigating)
                _buildNavigationPanel(navigationProvider),

              if (navigationProvider.state == NavigationState.searching)
                const Center(child: CircularProgressIndicator()),

              if (navigationProvider.errorMessage.isNotEmpty)
                _buildErrorMessage(navigationProvider),
            ],
          );
        },
      ),
      floatingActionButton: _buildFloatingActions(),
    );
  }

  Widget _buildSearchPanel(NavigationProvider provider) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 20,
      right: 20,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.directions, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  "Plan Your Route",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _toggleSearchPanel,
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Start Location Field
            _buildLocationField(
              controller: _startController,
              label: "Start Location",
              hint: "Current location or search...",
              onSet: () => _setStartLocation(provider),
              icon: Icons.play_arrow,
              color: Colors.green,
            ),
            const SizedBox(height: 12),

            // Swap Locations Button
            IconButton(
              onPressed: _swapLocations,
              icon: Icon(
                Icons.swap_vert,
                color: Theme.of(context).primaryColor,
                size: 28,
              ),
            ),

            // End Location Field
            _buildLocationField(
              controller: _endController,
              label: "End Location",
              hint: "Enter destination...",
              onSet: () => _setEndLocation(provider),
              icon: Icons.flag,
              color: Colors.red,
            ),
            const SizedBox(height: 16),

            // Find Routes Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: provider.state == NavigationState.searching
                    ? null
                    : () {
                        if (provider.startLocation != null &&
                            provider.endLocation != null) {
                          provider.searchRoutes();
                          _toggleSearchPanel();
                          _toggleRoutePanel();
                        } else {
                          _showSnackBar(
                            "Please set both start and end locations",
                            Colors.orange,
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
                child: provider.state == NavigationState.searching
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Find Routes",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required VoidCallback onSet,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: color, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onTap: onSet,
                readOnly: false,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                onPressed: onSet,
                icon: Icon(icon, color: color),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRouteSelectionPanel(NavigationProvider provider) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.route, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "${provider.routes.length} Route${provider.routes.length > 1 ? 's' : ''} Found",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _toggleRoutePanel,
                  icon: const Icon(Icons.close),
                  tooltip: "Close",
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Travel Profile Selector
            _buildProfileSelector(provider),

            const SizedBox(height: 16),

            // Route Options - Horizontal Scroll
            SizedBox(
              height: 140,
              child: provider.routes.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.route, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            "No routes found",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: provider.routes.length,
                      itemBuilder: (context, index) {
                        final route = provider.routes[index];
                        final isSelected =
                            provider.selectedRoute?.id == route.id;
                        final color = _getRouteColor(index);

                        return _buildRouteOptionCard(
                          route,
                          isSelected,
                          color,
                          index,
                          provider,
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _toggleRoutePanel();
                      _toggleSearchPanel();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: provider.selectedRoute != null
                        ? () {
                            provider.startNavigation();
                            _toggleRoutePanel();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.navigation, size: 20),
                        SizedBox(width: 8),
                        Text('Start Navigation'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSelector(NavigationProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.travel_explore, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          const Text(
            'Travel by:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: provider.selectedProfile,
            onChanged: (value) {
              if (value != null) {
                provider.setProfile(value);
                provider.searchRoutes();
              }
            },
            items: const [
              DropdownMenuItem(
                value: 'driving-car',
                child: Row(
                  children: [
                    Icon(Icons.directions_car, size: 18),
                    SizedBox(width: 6),
                    Text('Car'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'cycling-regular',
                child: Row(
                  children: [
                    Icon(Icons.directions_bike, size: 18),
                    SizedBox(width: 6),
                    Text('Bike'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'foot-walking',
                child: Row(
                  children: [
                    Icon(Icons.directions_walk, size: 18),
                    SizedBox(width: 6),
                    Text('Walk'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteOptionCard(
    RouteOption route,
    bool isSelected,
    Color color,
    int index,
    NavigationProvider provider,
  ) {
    return GestureDetector(
      onTap: () => provider.selectRoute(route),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route Header
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Route ${index + 1}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                if (index == 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'BEST',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),

            // Route Details
            Text(
              '${(route.distance / 1000).toStringAsFixed(1)} km',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),

            Text(
              _formatDuration(route.duration),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),

            const Spacer(),

            // Selection Indicator
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      "SELECTED",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationPanel(NavigationProvider provider) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Bar with percentage
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: provider.progress,
                      backgroundColor: Colors.grey[300],
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(provider.progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Navigation Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${(provider.remainingDistance / 1000).toStringAsFixed(1)} km to go',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ETA: ${_formatETA(provider.eta)}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: provider.stopNavigation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.stop, size: 20),
                    label: const Text('Stop'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage(NavigationProvider provider) {
    return Positioned(
      top: 200,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red),
        ),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(child: Text(provider.errorMessage)),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: provider.clear,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActions() {
    return Consumer<NavigationProvider>(
      builder: (context, provider, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show Search Panel Button
            if (!_showSearchPanel && !provider.isNavigating)
              FloatingActionButton(
                onPressed: _toggleSearchPanel,
                heroTag: 'show_search',
                mini: true,
                backgroundColor: Colors.blue,
                child: const Icon(Icons.directions, color: Colors.white),
              ),

            const SizedBox(height: 8),

            // My Location Button
            FloatingActionButton(
              onPressed: _centerToMyLocation,
              heroTag: 'location',
              mini: true,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
            const SizedBox(height: 8),

            // Routes Button (only show when routes are available)
            if (provider.state == NavigationState.routesReady &&
                !_showRoutePanel &&
                !provider.isNavigating)
              FloatingActionButton(
                onPressed: _toggleRoutePanel,
                heroTag: 'routes',
                mini: true,
                backgroundColor: Colors.green,
                child: const Icon(Icons.route, color: Colors.white),
              ),

            const SizedBox(height: 8),

            // Clear Button (only show when not idle)
            if (provider.state != NavigationState.idle &&
                !provider.isNavigating)
              FloatingActionButton(
                onPressed: () {
                  provider.clear();
                  _startController.clear();
                  _endController.clear();
                  setState(() {
                    _showRoutePanel = false;
                    _showSearchPanel = true;
                  });
                },
                heroTag: 'clear',
                mini: true,
                backgroundColor: Colors.red,
                child: const Icon(Icons.clear, color: Colors.white),
              ),
          ],
        );
      },
    );
  }

  Color _getRouteColor(int index) {
    final colors = [
      Colors.blue.shade700,
      Colors.green.shade700,
      Colors.orange.shade700,
      Colors.purple.shade700,
      Colors.red.shade700,
    ];
    return colors[index % colors.length];
  }

  String _formatDuration(double seconds) {
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

  String _formatETA(Duration eta) {
    if (eta.inHours > 0) {
      return '${eta.inHours}h ${eta.inMinutes.remainder(60)}m';
    } else if (eta.inMinutes > 0) {
      return '${eta.inMinutes}m';
    } else {
      return 'Less than a minute';
    }
  }

  void _onMapTap(LatLng latLng, NavigationProvider provider) {
    _showLocationSelectionDialog(latLng, provider);
  }

  void _showLocationSelectionDialog(LatLng point, NavigationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Set Location"),
        content: const Text(
          "Choose whether to set this as start or end location:",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _setLocationByTap(point, true, provider);
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow, color: Colors.green),
                SizedBox(width: 4),
                Text("Start", style: TextStyle(color: Colors.green)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _setLocationByTap(point, false, provider);
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flag, color: Colors.red),
                SizedBox(width: 4),
                Text("End", style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _setLocationByTap(
    LatLng point,
    bool isStart,
    NavigationProvider provider,
  ) {
    if (isStart) {
      provider.setStartLocation(point);
      _startController.text =
          "${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}";
    } else {
      provider.setEndLocation(point);
      _endController.text =
          "${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}";
    }
    _showSnackBar(
      "${isStart ? 'Start' : 'End'} location set by tap",
      Colors.blue,
    );
  }

  void _setStartLocation(NavigationProvider provider) {
    _openLocationSearch(true);
  }

  void _setEndLocation(NavigationProvider provider) {
    _openLocationSearch(false);
  }

  void _swapLocations() {
    final provider = Provider.of<NavigationProvider>(context, listen: false);
    if (provider.startLocation == null || provider.endLocation == null) {
      _showSnackBar("Both locations must be set to swap", Colors.orange);
      return;
    }

    final temp = provider.startLocation;
    provider.setStartLocation(provider.endLocation!);
    provider.setEndLocation(temp!);

    final tempText = _startController.text;
    _startController.text = _endController.text;
    _endController.text = tempText;

    _showSnackBar("Locations swapped", Colors.blue);
  }

  void _openLocationSearch(bool isStartLocation) async {
    final selectedName = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LocationSearchPage(isStartLocation: isStartLocation),
      ),
    );

    // If no location was selected, do nothing
    if (selectedName == null) return;

    // UPDATE THE TEXT FIELD HERE
    setState(() {
      if (isStartLocation) {
        _startController.text = selectedName;
      } else {
        _endController.text = selectedName;
      }
    });
  }

  Future<void> _centerToMyLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar("Please enable location services", Colors.orange);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar("Location permissions are denied", Colors.red);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar(
          "Location permissions are permanently denied",
          Colors.red,
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _checkNearbyPotholes(position);

      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            16.0,
          ),
        );

        final provider = Provider.of<NavigationProvider>(
          context,
          listen: false,
        );
        provider.setStartLocation(
          LatLng(position.latitude, position.longitude),
          isCurrentLocation: true,
        );
        _startController.text = "Current Location";
      }
    } catch (e) {
      print('Error getting location: $e');
      _showSnackBar("Unable to get current location", Colors.red);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
