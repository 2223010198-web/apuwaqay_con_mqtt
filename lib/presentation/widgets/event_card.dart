import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/models/huayco_event.dart'; // Importamos el modelo nuevo

class EventCard extends StatelessWidget {
  final HuaycoEvent event;
  final Function(LatLng)? onMap;
  final VoidCallback? onTap;

  const EventCard({super.key, required this.event, this.onMap, this.onTap});

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'Alta': return Colors.red;
      case 'Media': return Colors.orange;
      default: return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: _getSeverityColor(event.severity).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text("Severidad: ${event.severity}", style: TextStyle(color: _getSeverityColor(event.severity), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                Text(event.date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            Text(event.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(children: [const Icon(Icons.location_on, size: 14, color: Colors.grey), const SizedBox(width: 4), Text(event.location, style: const TextStyle(color: Colors.grey, fontSize: 13))]),
            const SizedBox(height: 10),
            Text(event.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black87)),
            const SizedBox(height: 10),
            const Align(alignment: Alignment.centerRight, child: Text("Ver detalles >", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12))),
          ],
        ),
      ),
    );
  }
}