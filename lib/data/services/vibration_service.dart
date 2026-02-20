import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';

class VibrationService {
  // Patrón Singleton para poder llamarlo desde el segundo plano sin perder la referencia
  static final VibrationService _instance = VibrationService._internal();
  factory VibrationService() => _instance;
  VibrationService._internal();

  Timer? _vibrationTimer;

  // --- MODO PRECAUCIÓN: Vibra por 6 segundos (una vez cada 2 segundos) ---
  Future<void> startPrecautionVibration() async {
    stopVibration(); // Reiniciar cualquier vibración previa
    bool canVibrate = await Vibrate.canVibrate;
    if (!canVibrate) return;

    int elapsed = 0;
    Vibrate.vibrate(); // Primera vibración inmediata

    _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      elapsed += 2;
      if (elapsed >= 6) {
        stopVibration();
      } else {
        Vibrate.vibrate();
      }
    });
    debugPrint("📳 Iniciada vibración de Precaución (6s)");
  }

  // --- MODO PELIGRO: Vibra por 12 segundos (patrón intenso cada 4 segundos) ---
  Future<void> startDangerVibration() async {
    stopVibration();
    bool canVibrate = await Vibrate.canVibrate;
    if (!canVibrate) return;

    int elapsed = 0;
    _triggerIntensePattern();

    _vibrationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      elapsed += 4;
      if (elapsed >= 12) {
        stopVibration();
      } else {
        _triggerIntensePattern();
      }
    });
    debugPrint("🚨 Iniciada vibración de Peligro (12s)");
  }

  // Patrón de vibración más fuerte para alerta roja
  void _triggerIntensePattern() {
    Vibrate.vibrateWithPauses([
      const Duration(milliseconds: 100), // Pausa
      const Duration(milliseconds: 800), // Vibra fuerte
      const Duration(milliseconds: 200), // Pausa
      const Duration(milliseconds: 800), // Vibra fuerte
    ]);
  }

  // --- DETENER VIBRACIÓN DE GOLPE ---
  void stopVibration() {
    if (_vibrationTimer != null && _vibrationTimer!.isActive) {
      _vibrationTimer!.cancel();
      _vibrationTimer = null;
      debugPrint("🛑 Vibración cancelada por el usuario o fin de tiempo.");
    }
  }
}