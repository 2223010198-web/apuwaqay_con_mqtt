import 'package:latlong2/latlong.dart';

class HuaycoEvent {
  final String id;
  final String titulo;
  final String fecha;
  final String lugar;
  final String fuente;
  final String descripcion;
  final String impacto;
  final List<String> imagenes;
  final LatLng? coordenadas;

  HuaycoEvent({
    required this.id,
    required this.titulo,
    required this.fecha,
    required this.lugar,
    required this.fuente,
    required this.descripcion,
    required this.impacto,
    required this.imagenes,
    this.coordenadas,
  });

  factory HuaycoEvent.fromFirestore(Map<String, dynamic> json, String documentId) {
    List<String> parsedImages = [];
    if (json['imagenes'] != null) {
      parsedImages = List<String>.from(json['imagenes']);
    }

    // --- NUEVA LÓGICA: CONVERSIÓN DE TEXTO (String) A LATLNG ---
    LatLng? parsedCoords;
    if (json['coordenadas'] != null && json['coordenadas'] is String) {
      try {
        // Cortamos el texto por la coma. Ejemplo: "-12.18, -76.94" -> ["-12.18", " -76.94"]
        List<String> parts = json['coordenadas'].split(',');

        if (parts.length == 2) {
          // trim() limpia los espacios en blanco antes y después del número
          double lat = double.parse(parts[0].trim());
          double lng = double.parse(parts[1].trim());
          parsedCoords = LatLng(lat, lng);
        }
      } catch (e) {
        // Si alguien escribió mal en Firebase (ej. puso letras), evitamos que la app colapse
        parsedCoords = null;
      }
    }

    return HuaycoEvent(
      id: documentId,
      titulo: json['titulo'] ?? 'Sin título',
      fecha: json['fecha'] ?? 'Fecha desconocida',
      lugar: json['lugar'] ?? 'Lugar no especificado',
      fuente: json['fuente'] ?? 'Fuente desconocida',
      descripcion: json['descripcion'] ?? 'Sin descripción',
      impacto: json['impacto'] ?? 'No registrado',
      imagenes: parsedImages,
      coordenadas: parsedCoords, // <--- Se asigna el LatLng ya convertido
    );
  }
}