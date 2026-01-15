import 'package:latlong2/latlong.dart';

class HuaycoEvent {
  final String title;
  final String date;
  final String location;
  final String severity; // 'Alta', 'Media', 'Baja'
  final String description;
  final String source;
  final LatLng coords;
  final List<String> images;

  HuaycoEvent({
    required this.title,
    required this.date,
    required this.location,
    required this.severity,
    required this.description,
    required this.source,
    required this.coords,
    required this.images,
  });
}