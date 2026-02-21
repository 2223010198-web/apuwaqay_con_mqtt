import 'package:flutter/material.dart';
import '../../domain/models/huayco_event.dart';

class EventCard extends StatelessWidget {
  final HuaycoEvent event;
  final VoidCallback onTap;

  const EventCard({super.key, required this.event, required this.onTap});

  // Determina el color dinámico según el impacto (Severidad)
  Color _getSeverityColor(String impacto) {
    final text = impacto.toLowerCase();
    if (text.contains('alt') || text.contains('grav') || text.contains('fuerte') || text.contains('desastre')) {
      return Colors.red;
    } else if (text.contains('medi') || text.contains('regular') || text.contains('moderado')) {
      return Colors.orange;
    }
    return Colors.green;
  }

  // Extrae una palabra corta (Alta, Media, Baja) para el diseño del "Pill"
  String _getSeverityLabel(String impacto) {
    final text = impacto.toLowerCase();
    if (text.contains('alt') || text.contains('grav') || text.contains('fuerte') || text.contains('desastre')) {
      return "Alta";
    } else if (text.contains('medi') || text.contains('regular') || text.contains('moderado')) {
      return "Media";
    }
    return "Baja";
  }

  @override
  Widget build(BuildContext context) {
    final severityColor = _getSeverityColor(event.impacto);
    final severityLabel = _getSeverityLabel(event.impacto);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // El margen horizontal lo quitamos porque la lista en history_screen ya tiene padding
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- 1. IMAGEN A LA IZQUIERDA ---
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: event.imagenes.isNotEmpty
                  ? Image.network(
                event.imagenes[0], // Toma la primera imagen del array
                width: 100,
                height: 135, // Altura fija para que encaje con el bloque de texto
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              )
                  : _buildPlaceholder(),
            ),
            const SizedBox(width: 12),

            // --- 2. CONTENIDO A LA DERECHA (Tu diseño exacto) ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Fila 1: Nivel de Severidad y Fecha
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: severityColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20)
                        ),
                        child: Text(
                            "Nivel: $severityLabel",
                            style: TextStyle(color: severityColor, fontWeight: FontWeight.bold, fontSize: 11)
                        ),
                      ),
                      Text(event.fecha, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Fila 2: Título
                  Text(
                    event.titulo,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Fila 3: Ubicación con ícono
                  Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(
                              event.lugar,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                        )
                      ]
                  ),
                  const SizedBox(height: 6),

                  // Fila 4: Descripción
                  Text(
                      event.descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.black87)
                  ),
                  const SizedBox(height: 8),

                  // Fila 5: "Ver detalles >"
                  const Align(
                      alignment: Alignment.centerRight,
                      child: Text("Ver detalles >", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12))
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget comodín si no hay foto
  Widget _buildPlaceholder() {
    return Container(
      width: 100,
      height: 135,
      color: Colors.grey[100],
      child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
    );
  }
}