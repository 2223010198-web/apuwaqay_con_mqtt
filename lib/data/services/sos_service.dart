// lib/data/services/sos_service.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

class SosService {
  static const platform = MethodChannel('com.apuwaqay/sms');

  Future<int> sendSOSAlert({
    required Position? position,
    required String userName,
    required bool isAuto,
    required bool isTracking,
  }) async {
    if (position == null) {
      debugPrint("❌ No hay coordenadas, no se puede enviar SOS exacto.");
      return 0;
    }

    final prefs = await SharedPreferences.getInstance();
    String c1 = prefs.getString('sos_contact_1') ?? "";
    String c2 = prefs.getString('sos_contact_2') ?? "";

    List<String> recipients = ["115"];
    if (c1.isNotEmpty) recipients.add(c1);
    if (c2.isNotEmpty) recipients.add(c2);

    // Corrección del link de Google Maps para que sea clickeable y exacto
    String mapsLink = "https://maps.google.com/?q=${position.latitude},${position.longitude}";
    String typeMsg = isAuto ? "[ALERTA AUTOMÁTICA]" : (isTracking ? "[RASTREO ACTIVO]" : "[UBICACIÓN FIJA]");
    String msg = "¡SOS HUAYCO! Soy $userName. $typeMsg: $mapsLink";

    int successCount = 0;

    for (String number in recipients) {
      try {
        // AHORA ESPERAMOS LA CONFIRMACIÓN REAL DEL BROADCAST RECEIVER DE ANDROID
        final bool? result = await platform.invokeMethod<bool>('sendDirectSMS', {
          "phone": number,
          "msg": msg
        });

        // Solo incrementamos si Android confirma que salió de la antena (RESULT_OK)
        if (result == true) {
          successCount++;
          debugPrint("✅ SMS CONFIRMADO por la red hacia: $number");
        } else {
          debugPrint("⚠️ SMS reportado como NO enviado por el sistema hacia: $number");
        }
      } on PlatformException catch (e) {
        // Control de errores mapeados desde el código nativo Kotlin
        debugPrint("❌ FALLO NATIVO SMS a $number: [${e.code}] - ${e.message}");
      } catch (e) {
        debugPrint("❌ Error inesperado de plataforma enviando a $number: $e");
      }
    }

    return successCount;
  }
}