import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeocodingService {
  static Future<LatLng?> fetchCoordinates(String query) async {
    try {
      final url = Uri.parse(
        "https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1",
      );

      final response = await http.get(
        url,
        headers: {"User-Agent": "Flutter-App"},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          return LatLng(lat, lon);
        }
      }

      return null;
    } catch (e) {
      print("Geocoding Error: $e");
      return null;
    }
  }
}
