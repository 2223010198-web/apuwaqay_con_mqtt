import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:telephony/telephony.dart';

class SosService {
  final Telephony telephony = Telephony.instance;

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
    await prefs.reload(); // Asegurar datos frescos en segundo plano

    String c1 = prefs.getString('sos_contact_1') ?? "";
    String c2 = prefs.getString('sos_contact_2') ?? "";

    Set<String> recipients = {"968892408"}; // Central de INDECI
    if (c1.isNotEmpty) recipients.add(c1);
    if (c2.isNotEmpty) recipients.add(c2);

    String mapsLink = "https://maps.google.com/?q=${position.latitude},${position.longitude}";
    String typeMsg = isAuto ? "[ALERTA AUTOMÁTICA]" : (isTracking ? "[RASTREO ACTIVO]" : "[UBICACIÓN FIJA]");
    String msg = "¡SOS HUAYCO! Soy $userName. $typeMsg: $mapsLink";

    int successCount = 0;

    // ENVÍO RELÁMPAGO (Sin bloqueos, sin Completers)
    for (String number in recipients) {
      try {
        // Dispara la orden directa a la antena del celular
        telephony.sendSms(
          to: number,
          message: msg,
          // NOTA: isMultipart se ha eliminado a propósito para garantizar velocidad
        );

        successCount++;
        debugPrint("🚀 Orden relámpago enviada a la antena para: $number");

        // Un micro-retraso imperceptible de 300ms para no saturar el módem
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        debugPrint("❌ Error enviando a $number: $e");
      }
    }

    return successCount;
  }
}