import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:new_mapper/pages/results_page.dart';
import 'package:new_mapper/services/pothole_monitor_service.dart';
import 'package:new_mapper/widgets/circular_button.dart';
import 'package:new_mapper/widgets/sensor_card.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool gpsActive = false;
  bool gyroscopeActive = false;
  bool accelerometerActive = false;
  bool isMonitoring = false;
  int potholeCount = 0;
  String gpsStatus = "Checking...";
  bool isCheckingGPS = false;

  final PotholeMonitorService _monitorService = PotholeMonitorService();

  // Simplified GPS check that actually tests location access
  Future<void> _checkGPSStatus() async {
    if (isCheckingGPS) return;

    setState(() {
      isCheckingGPS = true;
      gpsStatus = "Testing GPS...";
    });

    try {
      print("🔍 Starting GPS check...");

      // Method 1: Try to get current position first (most reliable)
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ).timeout(Duration(seconds: 15));

        print(
          "✅ GPS test successful: ${position.latitude}, ${position.longitude}",
        );

        setState(() {
          gpsActive = true;
          gpsStatus = "GPS Active - Location acquired";
        });
        return;
      } catch (e) {
        print("❌ getCurrentPosition failed: $e");
      }

      // Method 2: Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print("📍 Location service enabled: $serviceEnabled");

      if (!serviceEnabled) {
        setState(() {
          gpsActive = false;
          gpsStatus = "Location services disabled on device";
        });
        return;
      }

      // Method 3: Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      print("🔐 Location permission: $permission");

      if (permission == LocationPermission.denied) {
        setState(() {
          gpsActive = false;
          gpsStatus = "Location permission denied";
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          gpsActive = false;
          gpsStatus = "Location permission permanently denied";
        });
        return;
      }

      // Method 4: Try to get last known position
      try {
        Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          print(
            "✅ Last known position: ${lastPosition.latitude}, ${lastPosition.longitude}",
          );
          setState(() {
            gpsActive = true;
            gpsStatus = "GPS Active - Using last known location";
          });
          return;
        }
      } catch (e) {
        print("❌ Last known position failed: $e");
      }

      // If we reach here, GPS is not working properly
      setState(() {
        gpsActive = false;
        gpsStatus = "GPS available but cannot get location";
      });
    } catch (e) {
      print("❌ GPS check error: $e");
      setState(() {
        gpsActive = false;
        gpsStatus = "GPS check failed: ${e.toString()}";
      });
    } finally {
      setState(() {
        isCheckingGPS = false;
      });
    }
  }

  // Force GPS to work by requesting permissions and testing
  Future<void> _forceEnableGPS() async {
    setState(() {
      gpsStatus = "Attempting to enable GPS...";
    });

    try {
      // Request permission if needed
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          gpsStatus = "Please enable location permission in app settings";
        });
        openAppSettings();
        return;
      }

      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          gpsStatus = "Please enable location services on your device";
        });
        Geolocator.openLocationSettings();
        return;
      }

      // Test with a simple location request
      await _checkGPSStatus();
    } catch (e) {
      setState(() {
        gpsStatus = "Error enabling GPS: ${e.toString()}";
      });
    }
  }

  // Check sensors and permissions
  Future<void> _checkPermissionsAndSensors() async {
    // Check GPS status first
    await _checkGPSStatus();

    // Check accelerometer and gyroscope availability
    try {
      await userAccelerometerEventStream().first.timeout(const Duration(seconds: 2));
      setState(() {
        accelerometerActive = true;
      });
    } catch (_) {
      setState(() {
        accelerometerActive = false;
      });
    }

    try {
      await gyroscopeEventStream().first.timeout(const Duration(seconds: 2));
      setState(() {
        gyroscopeActive = true;
      });
    } catch (_) {
      setState(() {
        gyroscopeActive = false;
      });
    }
  }

  Future<void> _toggleMonitoring() async {
    // Allow monitoring even if GPS shows inactive (it might still work)
    if (!accelerometerActive || !gyroscopeActive) {
      _showSensorWarning();
      return;
    }

    if (isMonitoring) {
      // Stop monitoring
      await _monitorService.stopMonitoring();
      setState(() {
        isMonitoring = false;
      });

      // Navigate to results page
      _navigateToResults();
    } else {
      // Start monitoring even if GPS shows inactive
      // Sometimes GPS works during actual monitoring
      await _monitorService.startMonitoring();
      setState(() {
        isMonitoring = true;
        potholeCount = 0;
      });
    }
  }

  void _navigateToResults() {
    final potholes = _monitorService.getDetectedPotholes();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ResultsPage(potholes: potholes)),
    );
  }

  void _showSensorWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sensors Not Ready'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('GPS Status: $gpsStatus'),
            const SizedBox(height: 10),
            Text(
              'Accelerometer: ${accelerometerActive ? 'Active' : 'Inactive'}',
            ),
            Text('Gyroscope: ${gyroscopeActive ? 'Active' : 'Inactive'}'),
            const SizedBox(height: 10),
            const Text(
              'Accelerometer and Gyroscope are required for pothole detection.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Delay GPS check to let app initialize
    Future.delayed(Duration(seconds: 1), () {
      _checkPermissionsAndSensors();
    });
    _monitorService.loadPotholesFromStorage();

    // Listen for pothole updates
    _monitorService.potholesStream.listen((potholes) {
      if (mounted) {
        setState(() {
          potholeCount = potholes.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _monitorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "Sensor Dashboard",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkPermissionsAndSensors,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // GPS Status Card with better UI
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: gpsActive
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          gpsActive ? Icons.gps_fixed : Icons.gps_not_fixed,
                          color: gpsActive ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                gpsActive
                                    ? "GPS READY"
                                    : "GPS ATTENTION NEEDED",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: gpsActive
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                              Text(
                                gpsStatus,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: gpsActive
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isCheckingGPS)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                gpsActive ? Colors.green : Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (!gpsActive) ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _forceEnableGPS,
                        icon: Icon(Icons.gps_fixed),
                        label: Text('Fix GPS Issue'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Monitoring Status Card
            if (isMonitoring)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: Colors.orange.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "Monitoring Active - $potholeCount potholes detected",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            Center(
              child: CircularButton(
                isMonitoring: isMonitoring,
                onPressed: _toggleMonitoring,
              ),
            ),

            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Sensor Status",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            SensorStatusCard(
              icon: Icons.gps_fixed,
              name: "GPS (Location)",
              isActive: gpsActive,
              statusText: gpsStatus,
            ),

            SensorStatusCard(
              icon: Icons.speed,
              name: "Accelerometer",
              isActive: accelerometerActive,
            ),

            SensorStatusCard(
              icon: Icons.screen_rotation,
              name: "Gyroscope",
              isActive: gyroscopeActive,
            ),

            // Instructions & Troubleshooting
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    "Instructions:",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "1. Ensure all sensors are active (green)\n"
                    "2. Press START to begin monitoring\n"
                    "3. Ride your vehicle normally\n"
                    "4. Press STOP when finished to see results",
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),

                  if (!gpsActive) ...[
                    const SizedBox(height: 20),
                    Card(
                      color: Colors.orange.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Text(
                              "GPS Not Working? Try This:",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildTroubleshootStep(
                              "Press 'Fix GPS Issue' button above",
                              Icons.build,
                            ),
                            _buildTroubleshootStep(
                              "Go outside or near a window",
                              Icons.wb_sunny,
                            ),
                            _buildTroubleshootStep(
                              "Wait 30 seconds for GPS lock",
                              Icons.timer,
                            ),
                            _buildTroubleshootStep(
                              "Try starting monitoring anyway",
                              Icons.play_arrow,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Add some extra padding at the bottom for better scrolling
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTroubleshootStep(String text, IconData icon) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 16, color: Colors.orange),
      title: Text(text, style: GoogleFonts.poppins(fontSize: 12)),
    );
  }
}
