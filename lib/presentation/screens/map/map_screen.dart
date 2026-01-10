import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Librería de mapas
import 'package:latlong2/latlong.dart'; // Para manejar coordenadas GPS

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Coordenadas simuladas (Ejemplo: Una zona de quebrada en Lima/Andes)
  // Puedes cambiarlas por las de tu zona real buscando en Google Maps
  final LatLng sensorLocation = const LatLng(-11.95, -76.70);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mapa de Riesgos"),
        actions: [
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: () {
              // Aquí podrías cambiar entre vista Satelital / Terreno
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Cambiando capa de mapa...")),
              );
            },
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: sensorLocation, // Centrado en el sensor
              initialZoom: 14.5, // Zoom inicial
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all, // Permite mover y hacer zoom
              ),
            ),
            children: [
              // 1. CAPA BASE (Mapa callejero gratuito de OpenStreetMap)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.apuwaqay.app',
              ),

              // 2. CAPA DE ZONAS DE RIESGO (Polígonos)
              PolygonLayer(
                polygons: [
                  // ZONA ROJA: El cauce del huayco
                  Polygon(
                    points: [
                      LatLng(-11.940, -76.695),
                      LatLng(-11.950, -76.700), // Pasa por el sensor
                      LatLng(-11.960, -76.705),
                      LatLng(-11.958, -76.710),
                      LatLng(-11.945, -76.705),
                    ],
                    color: Colors.red.withOpacity(0.4), // Semitransparente
                    borderStrokeWidth: 2,
                    borderColor: Colors.red,
                    isFilled: true,
                  ),
                  // ZONA AMARILLA: Área de amortiguamiento
                  Polygon(
                    points: [
                      LatLng(-11.935, -76.690),
                      LatLng(-11.965, -76.715),
                      LatLng(-11.970, -76.700),
                      LatLng(-11.940, -76.685),
                    ],
                    color: Colors.orange.withOpacity(0.2),
                    borderStrokeWidth: 2,
                    borderColor: Colors.orange, // Sin borde
                    isFilled: true,
                  ),
                ],
              ),

              // 3. CAPA DE MARCADORES (Íconos)
              MarkerLayer(
                markers: [
                  // Marcador del Sensor IoT (Raspberry Pi)
                  Marker(
                    point: sensorLocation,
                    width: 50,
                    height: 50,
                    child: Column(
                      children: const [
                        Icon(Icons.router, color: Colors.blueAccent, size: 35),
                        Text("Gateway", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))
                      ],
                    ),
                  ),
                  // Marcador de "Refugio Seguro"
                  Marker(
                    point: const LatLng(-11.955, -76.685), // Un poco lejos del río
                    width: 50,
                    height: 50,
                    child: Column(
                      children: const [
                        Icon(Icons.home_filled, color: Colors.green, size: 35),
                        Text("Refugio", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green))
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 4. LEYENDA FLOTANTE (Para que el usuario entienda los colores)
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Leyenda de Riesgo", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  _buildLegendItem(Colors.red.withOpacity(0.6), "Cauce de Huayco (Peligro)"),
                  const SizedBox(height: 5),
                  _buildLegendItem(Colors.orange.withOpacity(0.6), "Zona de Riesgo Medio"),
                  const SizedBox(height: 5),
                  _buildLegendItem(Colors.green, "Refugio / Zona Segura"),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 15, height: 15, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}