import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: initSettingsAndroid);
    await _plugin.initialize(initSettings);
  }

  Future<void> showWarningNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'apu_waqay_alerts', 'Alertas de Huayco',
      importance: Importance.max, priority: Priority.high, ticker: 'ticker',
    );
    await _plugin.show(0, title, body, const NotificationDetails(android: androidDetails));
  }
}