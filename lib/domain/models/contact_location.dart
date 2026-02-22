// lib/domain/models/contact_location.dart
import 'package:latlong2/latlong.dart';

class ContactLocation {
  final String nombre;
  final String celular;
  final LatLng coordenadas;

  ContactLocation({
    required this.nombre,
    required this.celular,
    required this.coordenadas,
  });
}