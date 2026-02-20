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

    // Lista de destinatarios (Incluir INDECI o tu número de prueba)
    List<String> recipients = ["115"]; // Central de INDECI
    if (c1.isNotEmpty) recipients.add(c1);
    if (c2.isNotEmpty) recipients.add(c2);

    String mapsLink = "https://maps.google.com/?q=${position.latitude},${position.longitude}";
    String typeMsg = isAuto ? "[ALERTA AUTOMÁTICA]" : (isTracking ? "[RASTREO ACTIVO]" : "[UBICACIÓN FIJA]");
    String msg = "¡SOS HUAYCO! Soy $userName. $typeMsg: $mapsLink";

    int successCount = 0;
    for (String number in recipients) {
      try {
        await platform.invokeMethod('sendDirectSMS', {"phone": number, "msg": msg});
        successCount++;
        debugPrint("✅ SMS enviado a $number");
      } catch (e) {
        debugPrint("❌ Error enviando SMS a $number: $e");
      }
    }
    return successCount;
  }
}