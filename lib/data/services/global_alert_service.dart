// lib/data/services/global_alert_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart'; // Necesario para LatLng

import 'location_service.dart';
import 'sos_service.dart';
import 'notification_service.dart';
import 'vibration_service.dart';
import 'firebase_service.dart'; // 1️⃣ Conexión directa con FirebaseService

enum EmergencyState {
  normal,
  preventivo,
  alertaRoja,
  emergenciaActiva,
  emergenciaFinalizada
}

class GlobalAlertService {
  static final GlobalAlertService _instance = GlobalAlertService._internal();
  factory GlobalAlertService() => _instance;
  GlobalAlertService._internal();

  final LocationService _locationService = LocationService();
  final SosService _sosService = SosService();
  final NotificationService _notificationService = NotificationService();
  final VibrationService _vibrationService = VibrationService();
  final FirebaseService _firebaseService = FirebaseService();

  final StreamController<String> _eventStreamController = StreamController<String>.broadcast();
  Stream<String> get eventStream => _eventStreamController.stream;

  StreamSubscription<DocumentSnapshot>? _firestoreSubscription;

  EmergencyState _currentState = EmergencyState.normal;
  int _currentAlertLevel = 0;
  bool _isInitialized = false;

  bool _smsSentForCurrentEvent = false;
  bool _trackingActiveForCurrentEvent = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _notificationService.init();

    _firestoreSubscription = FirebaseFirestore.instance
        .collection('sensores')
        .doc('monitor_principal')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _processIncomingData(snapshot.data() as Map<String, dynamic>);
      }
    });
  }

  void _processIncomingData(Map<String, dynamic> data) async {
    int newLevel = (data['nivel_alerta'] ?? 0 as num).toInt();

    if (newLevel != _currentAlertLevel) {
      _currentAlertLevel = newLevel;
      await _transitionState(newLevel);
    } else {
      await evaluateReactiveConditions();
    }
  }

  Future<void> _transitionState(int level) async {
    _vibrationService.stopVibration();

    if (level == 0) {
      _currentState = EmergencyState.normal;
      _resetIdempotency();
      _locationService.stopTracking();

    } else if (level == 1) {
      _currentState = EmergencyState.preventivo;
      _resetIdempotency();
      _locationService.stopTracking();
      _notificationService.showPrecautionNotification();
      _vibrationService.startPrecautionVibration();

    } else if (level == 2) {
      _currentState = EmergencyState.alertaRoja;
      _notificationService.showDangerNotification();
      _vibrationService.startDangerVibration();
      await evaluateReactiveConditions();
    }
  }
  // --- CONTINUACIÓN: lib/data/services/global_alert_service.dart ---

  void _resetIdempotency() {
    _smsSentForCurrentEvent = false;
    _trackingActiveForCurrentEvent = false;
  }

  // 4️⃣ Evaluador Reactivo (Llamado al cambiar config o detectar alerta)
  Future<void> evaluateReactiveConditions() async {
    if (_currentAlertLevel != 2) return; // Evaluación estricta solo en ROJO

    final prefs = await SharedPreferences.getInstance();
    bool sosEnabled = prefs.getBool('sos_enabled') ?? true;
    bool autoSend = prefs.getBool('sos_auto_send') ?? false;
    bool realTime = prefs.getBool('sos_realtime') ?? false;
    String? miCelular = prefs.getString('userPhone');

    // A. Reactividad de Rastreo GPS -> CONEXIÓN DIRECTA E INMEDIATA A FIREBASE
    if (realTime && !_trackingActiveForCurrentEvent && !_locationService.isTracking) {
      _trackingActiveForCurrentEvent = true;

      _locationService.startTracking(onPositionUpdate: (position) {
        // 🚀 SUBIDA REACTIVA EN TIEMPO REAL: Cada pulso del GPS va a Firestore
        if (miCelular != null && miCelular.isNotEmpty) {
          _firebaseService.updateUbicacionActual(
              miCelular,
              LatLng(position.latitude, position.longitude)
          );
          debugPrint("☁️ FirebaseService: Ubicación de $miCelular actualizada en la nube.");
        }
      });

    } else if (!realTime && _locationService.isTracking) {
      _trackingActiveForCurrentEvent = false;
      _locationService.stopTracking();
    }

    // B. Reactividad de SMS Automático con Idempotencia
    if (sosEnabled && autoSend && !_smsSentForCurrentEvent) {
      _smsSentForCurrentEvent = true; // Bloqueo anti-race conditions
      _currentState = EmergencyState.emergenciaActiva;

      final position = await _locationService.getCurrentOrLastPosition();

      if (position != null) {
        String userName = prefs.getString('userName') ?? "Usuario";
        int count = await _sosService.sendSOSAlert(
          position: position,
          userName: userName,
          isAuto: true,
          isTracking: _locationService.isTracking,
        );

        if (count > 0) {
          _notificationService.showAutoSosNotification(count);
          _eventStreamController.add("✅ Alerta SOS automática enviada a $count contactos.");
        } else {
          _smsSentForCurrentEvent = false; // Libera token si falló para permitir reintento
        }
      } else {
        _smsSentForCurrentEvent = false; // Libera token si GPS falló
      }
    }
  }

  void dispose() {
    _firestoreSubscription?.cancel();
    _locationService.stopTracking();
    _eventStreamController.close();
    _isInitialized = false;
  }
}