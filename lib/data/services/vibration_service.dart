// lib/data/services/vibration_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';

class VibrationService {
  static final VibrationService _instance = VibrationService._internal();
  factory VibrationService() => _instance;
  VibrationService._internal();

  Timer? _vibrationTimer;

  Future<void> startPrecautionVibration() async {
    stopVibration();
    bool canVibrate = await Vibrate.canVibrate;
    if (!canVibrate) return;

    int elapsed = 0;
    Vibrate.vibrate();

    _vibrationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      elapsed += 4;
      if (elapsed >= 12) {
        stopVibration();
      } else {
        Vibrate.vibrate();
      }
    });
    debugPrint("📳 Iniciada vibración de Precaución (12s)");
  }

  Future<void> startDangerVibration() async {
    stopVibration();
    bool canVibrate = await Vibrate.canVibrate;
    if (!canVibrate) return;

    int elapsed = 0;
    _triggerIntensePattern();

    _vibrationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      elapsed += 5;
      if (elapsed >= 20) {
        stopVibration();
      } else {
        _triggerIntensePattern();
      }
    });
    debugPrint("🚨 Iniciada vibración de Peligro (20s)");
  }

  void _triggerIntensePattern() {
    Vibrate.vibrateWithPauses([
      const Duration(milliseconds: 100),
      const Duration(milliseconds: 800),
      const Duration(milliseconds: 200),
      const Duration(milliseconds: 800),
    ]);
  }

  void stopVibration() {
    if (_vibrationTimer != null && _vibrationTimer!.isActive) {
      _vibrationTimer!.cancel();
      _vibrationTimer = null;
      debugPrint("🛑 Vibración cancelada automáticamente o por el usuario.");
    }
  }
}
