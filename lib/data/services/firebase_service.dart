import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import '../../domain/models/huayco_event.dart';
import '../../domain/models/sensor_zone.dart';
import '../../domain/models/contact_location.dart'; // <--- AGREGAR ARRIBA
import 'package:latlong2/latlong.dart'; // <--- AGREGAR ARRIBA

class FirebaseService {
  // Instancia única de Firestore
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- 1. HISTORIAL DE DESASTRES ---
  Stream<List<HuaycoEvent>> getHistorialEventos() {
    return _db.collection('historial')
    // --- LA MAGIA DEL ORDENAMIENTO AQUÍ ---
    // descending: true hará que los más recientes salgan primero (arriba)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return HuaycoEvent.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  Stream<List<SensorZone>> getZonasYSensores() {
    return _db.collection('zonas_sensores').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return SensorZone.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }
  Future<void> updateUbicacionActual(String miCelular, LatLng posicion) async {
    try {
      await _db.collection('usuarios').doc(miCelular).update({
        'ubicacion_actual': '${posicion.latitude}, ${posicion.longitude}',
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Ignorar error si no hay internet, se actualizará en el próximo pulso
    }
  }

  // --- 4. ESCUCHAR A MIS CONTACTOS SOS (CONSENTIMIENTO MUTUO) ---
  Stream<List<ContactLocation>> streamMatchedContacts(String miCelular, List<String> misContactosSOS) {
    // 1. Filtro en la nube: Traer solo a quienes me tienen en su lista
    return _db.collection('usuarios')
        .where('contactos_sos', arrayContains: miCelular)
        .snapshots()
        .map((snapshot) {

      List<ContactLocation> activos = [];

      for (var doc in snapshot.docs) {
        // 2. Filtro local: Él me tiene, pero ¿yo lo tengo a él?
        if (misContactosSOS.contains(doc.id)) {
          String? ubi = doc.data()['ubicacion_actual'];

          if (ubi != null) {
            List<String> parts = ubi.split(',');
            if (parts.length == 2) {
              activos.add(ContactLocation(
                nombre: doc.data()['nombre'] ?? 'Familiar',
                celular: doc.id,
                coordenadas: LatLng(
                    double.parse(parts[0].trim()),
                    double.parse(parts[1].trim())
                ),
              ));
            }
          }
        }
      }
      return activos;
    });
  }

  
}
