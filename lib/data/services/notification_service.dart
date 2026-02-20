import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'vibration_service.dart';

// --- ESTA FUNCIÓN DEBE ESTAR FUERA DE LA CLASE (TOP-LEVEL) PARA EL SEGUNDO PLANO ---
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Si el usuario presiona las acciones de la notificación
  if (notificationResponse.actionId == 'action_alerta' ||
      notificationResponse.actionId == 'action_evacuando') {

    // Detiene la vibración inmediatamente en segundo plano
    VibrationService().stopVibration();
    debugPrint("✅ Botón presionado en segundo plano: ${notificationResponse.actionId}");
  }
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(android: initSettingsAndroid);

    // Inicializamos indicando qué hacer si la app está en primer o segundo plano
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Acciones en primer plano
        if (response.actionId == 'action_alerta' || response.actionId == 'action_evacuando') {
          VibrationService().stopVibration();
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  // 1. Notificación de PRECAUCIÓN con botón "Estoy en alerta"
  Future<void> showPrecautionNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'canal_precaucion',
      'Precaución de Huayco',
      importance: Importance.high,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('action_alerta', 'Estoy en alerta', showsUserInterface: true),
      ],
    );

    await _plugin.show(
        1,
        "⚠️ PRECAUCIÓN: Nivel del río subiendo",
        "Toque 'Estoy en alerta' para silenciar la vibración.",
        const NotificationDetails(android: androidDetails)
    );
  }

  // 2. Notificación de PELIGRO con botón "Estoy evacuando"
  Future<void> showDangerNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'canal_peligro',
      'Peligro Inminente',
      importance: Importance.max,
      priority: Priority.max,
      color: Color(0xFFCF0A2C), // Rojo
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('action_evacuando', 'Estoy evacuando', showsUserInterface: true),
      ],
    );

    await _plugin.show(
        2,
        "🚨 ¡ALERTA ROJA DE HUAYCO!",
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