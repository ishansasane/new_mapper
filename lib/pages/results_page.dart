import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:new_mapper/classes/pothole_data.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResultsPage extends StatefulWidget {
  final List<PotholeData> potholes;

  const ResultsPage({super.key, required this.potholes});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  bool isUploading = false;

  final supabase = Supabase.instance.client;

  void _openInMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  Future<void> _uploadToSupabase() async {
    if (widget.potholes.isEmpty) return;

    setState(() => isUploading = true);

    try {
      final data = widget.potholes.map((p) {
        return {
          'severity': p.severity,
          'latitude': p.latitude,
          'longitude': p.longitude,
          'detected_at': p.timestamp.toIso8601String(),
        };
      }).toList();

      await supabase.from('potholes').insert(data);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pothole data uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pothole Detection Results',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Summary Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Journey Summary',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(
                        'Total Potholes',
                        widget.potholes.length.toString(),
                        Icons.warning,
                      ),
                      _buildStatCard(
                        'Average Severity',
                        _calculateAverageSeverity().toStringAsFixed(2),
                        Icons.assessment,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // List
          Expanded(
            child: widget.potholes.isEmpty
                ? const Center(child: Text('No potholes detected'))
                : ListView.builder(
                    itemCount: widget.potholes.length,
                    itemBuilder: (context, index) {
                      final pothole = widget.potholes[index];
                      return _buildPotholeCard(pothole, index + 1);
                    },
                  ),
          ),

          // Upload Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(
                  isUploading ? 'Uploading...' : 'Upload Data to Supabase',
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
                onPressed: isUploading ? null : _uploadToSupabase,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.blue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 30, color: Colors.blue),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildPotholeCard(PotholeData pothole, int number) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getSeverityColor(pothole.severity),
          child: Text(
            number.toString(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text('Pothole #$number'),
        subtitle: Text(
          '${pothole.latitude}, ${pothole.longitude}\n'
          'Severity: ${pothole.severity.toStringAsFixed(2)}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.map),
          onPressed: () => _openInMaps(pothole.latitude, pothole.longitude),
        ),
      ),
    );
  }

  Color _getSeverityColor(double severity) {
    if (severity < 1.0) return Colors.green;
    if (severity < 2.0) return Colors.orange;
    return Colors.red;
  }

  double _calculateAverageSeverity() {
    if (widget.potholes.isEmpty) return 0.0;
    return widget.potholes.map((p) => p.severity).reduce((a, b) => a + b) /
        widget.potholes.length;
  }
}
