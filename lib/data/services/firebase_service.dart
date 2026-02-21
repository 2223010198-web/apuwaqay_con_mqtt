import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/huayco_event.dart';

class FirebaseService {
  // Instancia única de Firestore
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- 1. HISTORIAL DE DESASTRES ---
  // Retorna un "Stream" (flujo constante) de los eventos.
  // Si agregas algo en la web de Firebase, la app se actualizará sola sin recargar.
  Stream<List<HuaycoEvent>> getHistorialEventos() {
    return _db.collection('historial').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return HuaycoEvent.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

// (Aquí agregaremos después las funciones para el Mapa y Sensores)
}