import 'package:latlong2/latlong.dart';

class SensorZone {
  final String id;
  final LatLng? sensorCoords;
  final List<LatLng> zonaAlta;
  final List<LatLng> zonaMedia;
  final List<LatLng> zonaSegura;

  SensorZone({
    required this.id,
    this.sensorCoords,
    this.zonaAlta = const [],
    this.zonaMedia = const [],
    this.zonaSegura = const [],
  });

  factory SensorZone.fromFirestore(Map<String, dynamic> json, String documentId) {
    // Función auxiliar para convertir "-12.123, -76.123" a LatLng
    LatLng? parseCoord(dynamic coord) {
      if (coord is String) {
        try {
          final parts = coord.split(',');
          if (parts.length == 2) {
            return LatLng(double.parse(parts[0].trim()), double.parse(parts[1].trim()));
          }
        } catch (_) {}
      }
      return null;
    }

    // Función auxiliar para convertir un Array de Firebase a una Lista de LatLng
    List<LatLng> parsePolygon(dynamic coordsList) {
      if (coordsList is List) {
        return coordsList
            .map((coord) => parseCoord(coord))
            .where((c) => c != null) // Filtramos si alguna coordenada se escribió mal
            .cast<LatLng>()
            .toList();
      }
      return [];
    }

    return SensorZone(
      id: documentId,
      sensorCoords: parseCoord(json['sensor']),
      zonaAlta: parsePolygon(json['zona_alta']),
      zonaMedia: parsePolygon(json['zona_media']),
      zonaSegura: parsePolygon(json['zona_segura']),
    );
  }
}