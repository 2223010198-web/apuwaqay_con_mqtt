import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/huayco_event.dart';
import '../../domain/models/sensor_zone.dart';

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
}
