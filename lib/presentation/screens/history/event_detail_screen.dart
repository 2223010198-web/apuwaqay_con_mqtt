import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../domain/models/huayco_event.dart';

class EventDetailScreen extends StatelessWidget {
  final HuaycoEvent event;
  final Function(LatLng)? onMapRequest;
  final VoidCallback onBack;

  const EventDetailScreen({super.key, required this.event, this.onMapRequest, required this.onBack});

  // Determina el color dinámico basado en el texto del impacto/severidad
  Color _getSeverityColor(String impacto) {
    final text = impacto.toLowerCase();
    if (text.contains('alt') || text.contains('grav') || text.contains('fuerte') || text.contains('desastre')) {
      return Colors.red;
    } else if (text.contains('medi') || text.contains('regular') || text.contains('moderado')) {
      return Colors.orange;
    }
    return Colors.green; // Baja o sin riesgo
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Fondo claro Material Design

      // --- CONTENIDO DESLIZABLE ---
      body: SingleChildScrollView(
        // Agregamos padding inferior para que el texto final no se oculte detrás del botón flotante
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCustomHeader(context),
            _buildImageCarousel(),
            _buildSeverityBanner(),
            _buildDetailsSection(context),
          ],
        ),
      ),

      // --- BOTÓN FLOTANTE DE MAPA (ESTILO MATERIAL DESIGN) ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (event.coordenadas != null && onMapRequest != null) {
            onBack(); // Cierra la pantalla de detalles
            onMapRequest!(event.coordenadas!); // Ejecuta la función para ir al mapa
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Coordenadas no disponibles para este evento en la base de datos"))
            );
          }
        },
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.map),
        label: const Text("VER UBICACIÓN EN EL MAPA", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      // Posiciona el botón en la parte inferior central, flotando sobre la vista
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // --- 1. HEADER PERSONALIZADO ---
  Widget _buildCustomHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 10, right: 20, bottom: 10
      ),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: onBack, // Cierra la pantalla
          ),
          Expanded(
            child: Text(
                event.titulo,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. CARRUSEL DE IMÁGENES ---
  Widget _buildImageCarousel() {
    return SizedBox(
      height: 250,
      child: event.imagenes.isNotEmpty
          ? PageView.builder(
        itemCount: event.imagenes.length,
        itemBuilder: (context, index) {
          return Image.network(
            event.imagenes[index],
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator(color: Colors.red));
            },
            errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[300],
                child: const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey))
            ),
          );
        },
      )
          : Container(
        color: Colors.grey[200],
        child: const Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("Sin imágenes disponibles", style: TextStyle(color: Colors.grey))
                ]
            )
        ),
      ),
    );
  }

  // --- 3. BANNER DE SEVERIDAD DINÁMICO ---
  Widget _buildSeverityBanner() {
    final severityColor = _getSeverityColor(event.impacto);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: severityColor.withOpacity(0.2),
      child: Center(
          child: Text(
              "IMPACTO REGISTRADO: ${event.impacto.toUpperCase()}",
              style: TextStyle(
                  color: severityColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5
              )
          )
      ),
    );
  }

  // --- 4. SECCIÓN DE DETALLES ---
  Widget _buildDetailsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(icon: Icons.calendar_today, label: "Fecha:", value: event.fecha),
          _DetailRow(icon: Icons.location_on, label: "Ubicación:", value: event.lugar),
          _DetailRow(icon: Icons.source, label: "Fuente:", value: event.fuente),

          const SizedBox(height: 20),
          const Text("Descripción del Evento", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(event.descripcion, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87), textAlign: TextAlign.justify),

          // El botón se eliminó de aquí y pasó a ser FloatingActionButton en el Scaffold
        ],
      ),
    );
  }
}

// --- WIDGET AUXILIAR PARA LAS FILAS DE INFORMACIÓN ---
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: Colors.grey),
              const SizedBox(width: 10),
              SizedBox(
                  width: 80,
                  child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))
              ),
              Expanded(
                  child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))
              )
            ]
        )
    );
  }
}