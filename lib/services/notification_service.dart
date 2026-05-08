import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(settings);

    // Request notification permissions for Android 13+
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
  }

  static Future<void> showPotholeWarning(double severity) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'pothole_channel',
          'Pothole Alerts',
          channelDescription: 'Alerts when pothole is nearby',
          importance: Importance.high,
          priority: Priority.high,
        );

    await _notifications.show(
      0,
      '⚠️ Pothole Ahead',
      'Severity: ${severity.toStringAsFixed(0)}%',
      const NotificationDetails(android: androidDetails),
    );
  }
}
