import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mqtt_service.dart';
import 'location_service.dart';
import 'sos_service.dart';
import 'notification_service.dart';
import 'vibration_service.dart';

class GlobalAlertService {
  static final GlobalAlertService _instance = GlobalAlertService._internal();
  factory GlobalAlertService() => _instance;
  GlobalAlertService._internal();

  final MqttService _mqttService = MqttService();
  final LocationService _locationService = LocationService();
  final SosService _sosService = SosService();
  final NotificationService _notificationService = NotificationService();
  final VibrationService _vibrationService = VibrationService();

  // --- NUEVO: Canal para avisarle a la UI que muestre un Toast ---
  final StreamController<String> _eventStreamController = StreamController<String>.broadcast();
  Stream<String> get eventStream => _eventStreamController.stream;

  int _currentAlertLevel = 0;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _notificationService.init();
    await _mqttService.connect();

    _mqttService.dataStream.listen((data) {
      _processIncomingData(data);
    });
  }

  void _processIncomingData(Map<String, dynamic> data) async {
    int newLevel = (data['nivel_alerta'] ?? 0 as num).toInt();

    if (newLevel != _currentAlertLevel) {
      _currentAlertLevel = newLevel;
      await _triggerProtocols(newLevel);
    }
  }

  Future<void> _triggerProtocols(int level) async {
    _vibrationService.stopVibration();

    final prefs = await SharedPreferences.getInstance();
    bool sosEnabled = prefs.getBool('sos_enabled') ?? true;
    bool autoSend = prefs.getBool('sos_auto_send') ?? false;

    if (level == 1) {
      _notificationService.showPrecautionNotification();
      _vibrationService.startPrecautionVibration();

    } else if (level == 2) {
      _notificationService.showDangerNotification();
      _vibrationService.startDangerVibration();

      // AUTO-ENVÍO EN SEGUNDO PLANO
      if (sosEnabled && autoSend) {
        debugPrint("⚡ SEGUNDO PLANO: Enviando SOS automático...");

        final position = await _locationService.getCurrentOrLastPosition();
        String userName = prefs.getString('userName') ?? "Usuario";

        int count = await _sosService.sendSOSAlert(
          position: position,
          userName: userName,
          isAuto: true,
          isTracking: _locationService.isTracking,
        );

        // --- NUEVO: Notificar y mostrar Toast si fue exitoso ---
        if (count > 0) {
          debugPrint("⚡ SEGUNDO PLANO: SMS enviado a $count contactos.");

          // 1. Muestra la notificación en la barra superior (incluso si está cerrada)
          _notificationService.showAutoSosNotification(count);

          // 2. Avisa a la pantalla para que muestre el Toast (si está abierta)
          _eventStreamController.add("✅ Alerta SOS automática enviada a $count contactos.");
        }
      }
    }
  }
}