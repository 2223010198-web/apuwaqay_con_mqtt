// lib/data/services/notification_service.dart
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'vibration_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  if (notificationResponse.actionId == 'action_preparado' ||
      notificationResponse.actionId == 'action_evacuando') {
    VibrationService().stopVibration();
    debugPrint("✅ Botón presionado en segundo plano: ${notificationResponse.actionId}");
  }
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(android: initSettingsAndroid);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.actionId == 'action_preparado' || response.actionId == 'action_evacuando') {
          VibrationService().stopVibration();
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  Future<void> showPrecautionNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'canal_precaucion',
      'Precaución de Huayco',
      importance: Importance.high,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('action_preparado', 'Estoy preparado', showsUserInterface: true),
      ],
    );

    await _plugin.show(
        1,
        "⚠️ Riesgo de Huayco – Mantente preparado",
        "Toque 'Estoy preparado' para silenciar la vibración.",
        const NotificationDetails(android: androidDetails)
    );
  }

  Future<void> showDangerNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'canal_peligro',
      'Peligro Inminente',
      importance: Importance.max,
      priority: Priority.max,
      color: Color(0xFFCF0A2C),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('action_evacuando', 'Estoy evacuando', showsUserInterface: true),
      ],
    );

    await _plugin.show(
        2,
        "🚨 PELIGRO DE HUAYCO – EVACÚA AHORA",
        "Impacto inminente. ¡Evacúe a la zona segura ahora!",
        const NotificationDetails(android: androidDetails)
    );
  }

  Future<void> showAutoSosNotification(int count) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'canal_info',
      'Información del Sistema',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
        3,
        "✅ SOS Enviado con Éxito",
        "Tu ubicación fue enviada automáticamente a $count contactos.",
        const NotificationDetails(android: androidDetails)
    );
  }
}