// SOLO PARA DEMO
import 'package:cloud_firestore/cloud_firestore.dart';

class DemoModeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Escucha en tiempo real el documento de configuración
  Stream<Map<String, dynamic>?> getDemoState() {
    return _db.collection('configuracion')
        .doc('demostracion')
        .snapshots()
        .map((doc) => doc.data());
  }
}