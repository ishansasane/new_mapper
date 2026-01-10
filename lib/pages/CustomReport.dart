import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Customreport extends StatefulWidget {
  const Customreport({super.key});

  @override
  State<Customreport> createState() => _CustomreportState();
}

class _CustomreportState extends State<Customreport> {
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  double _severity = 50;
  bool _loadingLocation = false;
  bool _uploading = false;

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _loadingLocation = true);

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _latController.text = pos.latitude.toStringAsFixed(6);
      _lngController.text = pos.longitude.toStringAsFixed(6);
    } catch (e) {
      _showSnack('Location error: $e', Colors.red);
    }

    setState(() => _loadingLocation = false);
  }

  Future<void> _submitReport() async {
    if (_latController.text.isEmpty || _lngController.text.isEmpty) {
      _showSnack('Please enter latitude and longitude', Colors.orange);
      return;
    }

    setState(() => _uploading = true);

    try {
      await supabase.from('potholes').insert({
        'latitude': double.parse(_latController.text),
        'longitude': double.parse(_lngController.text),
        'severity': _severity,
        'detected_at': DateTime.now().toIso8601String(),
      });

      _showSnack('Pothole reported successfully', Colors.green);
      _latController.clear();
      _lngController.clear();
      setState(() => _severity = 50);
    } catch (e) {
      _showSnack('Upload failed: $e', Colors.red);
    }

    setState(() => _uploading = false);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report a Pothole'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Location',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lngController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: _loadingLocation ? null : _getCurrentLocation,
              icon: const Icon(Icons.my_location),
              label: Text(
                _loadingLocation ? 'Fetching...' : 'Use Current Location',
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Severity',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _severity,
              min: 0,
              max: 100,
              divisions: 10,
              label: '${_severity.toInt()}%',
              onChanged: (v) => setState(() => _severity = v),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _uploading ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(14),
                ),
                child: _uploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
