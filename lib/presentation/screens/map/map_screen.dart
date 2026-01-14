import 'dart:async';
import 'dart:convert'; // Para leer la respuesta del buscador
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Librería de mapas gratis
import 'package:latlong2/latlong.dart'; // Manejo de coordenadas
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http; // Para hacer búsquedas

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // --- CONTROLADORES ---
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  // --- ESTADOS ---
  bool _showZones = true; // Controla si se ven las zonas sombreadas
  List<dynamic> _searchResults = []; // Lista de lugares encontrados
  bool _isSearching = false;
  LatLng? _myPosition;

  // ---------------------------------------------------------------------------
  // 📍 ZONA EDITABLE: COORDENADAS
  // ---------------------------------------------------------------------------

  // Ubicación del Sensor Apu Waqay
  static const LatLng _apuWaqayLocation = LatLng(-12.155375, -76.923746);

  // Zona Roja (Peligro)
  final List<LatLng> _redZoneCoords = [
    const LatLng(-12.154000, -76.923000),
    const LatLng(-12.155375, -76.923746),
    const LatLng(-12.157000, -76.924500),
    const LatLng(-12.158500, -76.925000),
    const LatLng(-12.158000, -76.923000),
    const LatLng(-12.154500, -76.922000),
  ];

  // Zona Naranja (Riesgo Medio)
  final List<LatLng> _orangeZoneCoords = [
    const LatLng(-12.153000, -76.921000),
    const LatLng(-12.156000, -76.922000),
    const LatLng(-12.159000, -76.926000),
    const LatLng(-12.160000, -76.920000),
    const LatLng(-12.153000, -76.919000),
  ];

  // Zona Verde (Refugio)
  final List<LatLng> _safeZoneCoords = [
    const LatLng(-12.152000, -76.925000),
    const LatLng(-12.152000, -76.927000),
    const LatLng(-12.154000, -76.927000),
    const LatLng(-12.154000, -76.925000),
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // Obtener ubicación actual
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _myPosition = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint("Error obteniendo ubicación: $e");
    }
  }

  // Ir a mi ubicación
  void _goToMyLocation() {
    if (_myPosition != null) {
      _mapController.move(_myPosition!, 16.0);
    } else {
      _getCurrentLocation();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Obteniendo ubicación...")));
    }
  }

  // Función de Búsqueda (Nominatim OpenStreetMap API)
  Future<void> _searchPlaces(String query) async {
    if (query.length < 3) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      // API Gratuita de OpenStreetMap (Limitada a 1 solicitud por segundo, uso ético)
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5&addressdetails=1&countrycodes=pe'); // 'pe' limita a Perú

      final response = await http.get(url, headers: {
        'User-Agent': 'com.apuwaqay.app', // Identificador requerido por OSM
      });

      if (response.statusCode == 200) {
        setState(() {
          _searchResults = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error buscando: $e");
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Hacemos que el mapa ocupe todo, incluso detrás de la barra de estado
      body: Stack(
        children: [
          // 1. EL MAPA
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _apuWaqayLocation, // Centrado inicial en el sensor
              initialZoom: 15.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // Capa de Mapa Base (OpenStreetMap)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.apuwaqay.app',
              ),

              // Capa de Zonas (Polígonos) - Se muestra solo si _showZones es true
              if (_showZones)
                PolygonLayer(
                  polygons: [
                    // Zona Roja
                    Polygon(
                      points: _redZoneCoords,
                      color: Colors.red.withOpacity(0.4), // Sombreado
                      borderStrokeWidth: 2,
                      borderColor: Colors.red,
                      isFilled: true,
                    ),
                    // Zona Naranja
                    Polygon(
                      points: _orangeZoneCoords,
                      color: Colors.orange.withOpacity(0.3),
                      borderStrokeWidth: 2,
                      borderColor: Colors.orange,
                      isFilled: true,
                    ),
                    // Zona Verde
                    Polygon(
                      points: _safeZoneCoords,
                      color: Colors.green.withOpacity(0.4),
                      borderStrokeWidth: 2,
                      borderColor: Colors.green,
                      isFilled: true,
                    ),
                  ],
                ),

              // Capa de Marcadores (Iconos)
              MarkerLayer(
                markers: [
                  // Marcador Sensor Apu Waqay
                  Marker(
                    point: _apuWaqayLocation,
                    width: 50,
                    height: 50,
                    child: Image.asset('assets/images/logo.png'), // TU LOGO
                  ),

                  // Marcador Mi Ubicación (Si existe)
                  if (_myPosition != null)
                    Marker(
                      point: _myPosition!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                    ),
                ],
              ),
            ],
          ),

          // 2. BARRA SUPERIOR Y BUSCADOR
          Positioned(
            top: 40, // Espacio para la barra de estado
            left: 15,
            right: 15,
            child: Column(
              children: [
                Row(
                  children: [
                    // Botón Atrás
                    // Buscador
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _searchPlaces,
                          decoration: InputDecoration(
                            hintText: "Buscar zona...",
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            suffixIcon: _isSearching
                                ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.search),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Botón Toggle Zonas (Sombreado)
                    CircleAvatar(
                      backgroundColor: _showZones ? Colors.blue : Colors.white,
                      child: IconButton(
                        icon: Icon(Icons.layers, color: _showZones ? Colors.white : Colors.black),
                        onPressed: () {
                          setState(() {
                            _showZones = !_showZones;
                          });
                        },
                        tooltip: "Mostrar/Ocultar Zonas de Riesgo",
                      ),
                    ),
                  ],
                ),

                // Lista de Resultados de Búsqueda
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 10, left: 50, right: 50),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final place = _searchResults[index];
                        return ListTile(
                          title: Text(place['display_name'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                          leading: const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                          onTap: () {
                            // Mover mapa al lugar seleccionado
                            final lat = double.parse(place['lat']);
                            final lon = double.parse(place['lon']);
                            _mapController.move(LatLng(lat, lon), 16.0);

                            // Limpiar búsqueda
                            setState(() {
                              _searchResults = [];
                              _searchController.clear();
                            });
                            FocusScope.of(context).unfocus(); // Ocultar teclado
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 3. LEYENDA FLOTANTE (Abajo Izquierda)
          Positioned(
            bottom: 30,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Leyenda", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 5),
                  _legendItem(Colors.red, "Peligro Alto"),
                  _legendItem(Colors.orange, "Riesgo Medio"),
                  _legendItem(Colors.green, "Zona Segura"),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Image.asset('assets/images/logo.png', width: 20, height: 20),
                      const SizedBox(width: 5),
                      const Text("Apu Waqay", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),

      // 4. BOTÓN FLOTANTE UBICACIÓN (Abajo Derecha)
      floatingActionButton: FloatingActionButton(
        onPressed: _goToMyLocation,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }

  Widget _legendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color.withOpacity(0.6), border: Border.all(color: color))),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}