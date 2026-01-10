// pages/routes_selection_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../services/navigation_service.dart';

class RoutesSelectionPage extends StatelessWidget {
  const RoutesSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final navigationProvider = context.read<NavigationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Route'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: navigationProvider.searchRoutes,
            tooltip: 'Refresh Routes',
          ),
        ],
      ),
      body: Consumer<NavigationProvider>(
        builder: (context, provider, child) {
          if (provider.state == NavigationState.searching) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.routes.isEmpty) {
            return const Center(child: Text('No routes available'));
          }

          return Column(
            children: [
              // Travel Profile Selector
              _buildProfileSelector(provider),

              // Routes List
              Expanded(
                child: ListView.builder(
                  itemCount: provider.routes.length,
                  itemBuilder: (context, index) {
                    final route = provider.routes[index];
                    final isSelected = provider.selectedRoute?.id == route.id;
                    final color = NavigationService.getRouteColor(index);

                    return _buildRouteCard(
                      context,
                      route,
                      isSelected,
                      Color(color),
                      index,
                      provider,
                    );
                  },
                ),
              ),

              // Action Buttons
              _buildActionButtons(context, provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileSelector(NavigationProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Text('Travel by:'),
          const SizedBox(width: 16),
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
                    Icon(Icons.directions_car, size: 20),
                    SizedBox(width: 8),
                    Text('Car'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'cycling-regular',
                child: Row(
                  children: [
                    Icon(Icons.directions_bike, size: 20),
                    SizedBox(width: 8),
                    Text('Bike'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'foot-walking',
                child: Row(
                  children: [
                    Icon(Icons.directions_walk, size: 20),
                    SizedBox(width: 8),
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

  Widget _buildRouteCard(
    BuildContext context,
    RouteOption route,
    bool isSelected,
    Color color,
    int index,
    NavigationProvider provider,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isSelected ? color.withOpacity(0.1) : null,
      elevation: isSelected ? 4 : 2,
      child: ListTile(
        leading: Container(width: 4, height: 40, color: color),
        title: Text(
          'Route ${index + 1}',
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distance: ${(route.distance / 1000).toStringAsFixed(1)} km'),
            Text('Duration: ${_formatDuration(route.duration)}'),
            Text(route.summary),
          ],
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
        onTap: () => provider.selectRoute(route),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    NavigationProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (provider.errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                provider.errorMessage,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: provider.selectedRoute != null
                      ? () {
                          provider.startNavigation();
                          Navigator.pop(context);
                        }
                      : null,
                  child: const Text('Start Navigation'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}
