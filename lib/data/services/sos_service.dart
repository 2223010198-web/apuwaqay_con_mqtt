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

    List<String> recipients = ["968892408"];
    if (c1.isNotEmpty) recipients.add(c1);
    if (c2.isNotEmpty) recipients.add(c2);

    // Corrección sintáctica silenciosa en el string (agregado el $ faltante en latitude)
    String mapsLink = "https://maps.google.com/?q=${position.latitude},${position.longitude}";
    String typeMsg = isAuto ? "[ALERTA AUTOMÁTICA]" : (isTracking ? "[RASTREO ACTIVO]" : "[UBICACIÓN FIJA]");
    String msg = "¡SOS HUAYCO! Soy $userName. $typeMsg: $mapsLink";

    int successCount = 0;

    for (String number in recipients) {
      try {
        // Bloquea asíncronamente hasta que el BroadcastReceiver de Kotlin devuelva el resultado
        final bool? result = await platform.invokeMethod<bool>('sendDirectSMS', {
          "phone": number,
          "msg": msg
        });

        if (result == true) {
          successCount++;
          debugPrint("✅ SMS ENVIADO Y CONFIRMADO POR LA RED a: $number");
        } else {
          debugPrint("⚠️ SMS procesado pero sin confirmación de éxito a: $number");
        }
      } on PlatformException catch (e) {
        // Captura los códigos de error específicos que definimos en MainActivity.kt
        debugPrint("❌ FALLO NATIVO SMS a $number: [${e.code}] - ${e.message}");
      } catch (e) {
        debugPrint("❌ ERROR CRÍTICO enviando SMS a $number: $e");
      }
    }

    return successCount;
  }
}