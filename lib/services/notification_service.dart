import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final FlutterTts _flutterTts = FlutterTts();

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

    // Initialize TTS
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.55);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  static Future<void> showPotholeWarning(double severity, double distance) async {
    final int distStr = distance.round();
    final String speakMessage = 'Warning: Pothole approaching in $distStr meters';
    
    // Speak the warning
    await _flutterTts.speak(speakMessage);

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
      'Distance: $distStr meters',
      const NotificationDetails(android: androidDetails),
    );
  }
}
