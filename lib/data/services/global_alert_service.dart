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

  int _currentAlertLevel = 0;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _notificationService.init();
    await _mqttService.connect();

    // Escucha permanente en segundo plano
    _mqttService.dataStream.listen((data) {
      _processIncomingData(data);
    });
  }

  void _processIncomingData(Map<String, dynamic> data) async {
    int newLevel = (data['nivel_alerta'] ?? 0 as num).toInt();

    // Si el nivel cambió, activamos protocolos
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

    if (level == 1) { // PRECAUCIÓN
      _notificationService.showPrecautionNotification();
      _vibrationService.startPrecautionVibration();

    } else if (level == 2) { // PELIGRO INMINENTE
      _notificationService.showDangerNotification();
      _vibrationService.startDangerVibration();

      // LOGICA DE AUTO-ENVIO EN SEGUNDO PLANO
      if (sosEnabled && autoSend) {
        debugPrint("⚡ SEGUNDO PLANO: Huayco detectado. Enviando SOS automático...");

        final position = await _locationService.getCurrentOrLastPosition();
        String userName = prefs.getString('userName') ?? "Usuario";

        int count = await _sosService.sendSOSAlert(
          position: position,
          userName: userName,
          isAuto: true,
          isTracking: _locationService.isTracking,
        );
        debugPrint("⚡ SEGUNDO PLANO: SMS enviado a $count contactos.");
      }
    }
  }
}