import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../providers/navigation_provider.dart';
import '../services/location_service.dart';

class LocationSearchPage extends StatefulWidget {
  final bool isStartLocation;

  const LocationSearchPage({super.key, required this.isStartLocation});

  @override
  State<LocationSearchPage> createState() => _LocationSearchPageState();
}

class _LocationSearchPageState extends State<LocationSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final LocationService _locationService = LocationService();

  List<dynamic> _results = [];
  bool _loading = false;

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _loading = true);

    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=10",
    );

    try {
      final res = await http.get(url, headers: {"User-Agent": "flutter-app"});

      if (res.statusCode == 200) {
        setState(() {
          _results = json.decode(res.body);
          _loading = false;
        });
      } else {
        setState(() {
          _results = [];
          _loading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
      setState(() {
        _results = [];
        _loading = false;
      });
    }
  }

  void _select(dynamic place) {
    final provider = context.read<NavigationProvider>();

    final double lat = double.parse(place["lat"]);
    final double lon = double.parse(place["lon"]);

    final LatLng pos = LatLng(lat, lon);

    if (widget.isStartLocation) {
      provider.setStartLocation(pos);
    } else {
      provider.setEndLocation(pos);
    }

    // RETURN the display name to MapPage
    Navigator.pop(context, place["display_name"]);
  }

  Future<void> _useMyLocation() async {
    final pos = await _locationService.getCurrentLocation();
    if (pos == null) return;

    context.read<NavigationProvider>().setStartLocation(
      LatLng(pos.latitude, pos.longitude),
      isCurrentLocation: true,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isStartLocation ? "Set Start Location" : "Set Destination",
        ),
        actions: [
          if (widget.isStartLocation)
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: _useMyLocation,
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search place...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _results = []);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _search,
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                ? const Center(
                    child: Text("Search for any city, place or area"),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                        ),
                        title: Text(item["display_name"] ?? "Unknown"),
                        onTap: () => _select(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
