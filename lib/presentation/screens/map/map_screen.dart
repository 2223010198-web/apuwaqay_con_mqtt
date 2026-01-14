import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// 1. CLASE MODELO PARA AGRUPAR LOS DATOS DE CADA ZONA
class ApuZone {
  final String name;
  final LatLng sensorLocation;
  final List<LatLng> redZone;
  final List<LatLng> orangeZone;
  final List<LatLng> greenZone;

  ApuZone({
    required this.name,
    required this.sensorLocation,
    required this.redZone,
    required this.orangeZone,
    required this.greenZone,
  });
}

class MapScreen extends StatefulWidget {
  final LatLng? focusLocation;

  const MapScreen({super.key, this.focusLocation});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  bool _showZones = true;
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  LatLng? _myPosition;

  // ---------------------------------------------------------------------------
  // 📍 BASE DE DATOS DE ZONAS (EDITABLE)
  // ---------------------------------------------------------------------------
  final List<ApuZone> _allZones = [
    // ZONA 1: VILLA MARÍA DEL TRIUNFO (Original)
    ApuZone(
      name: "VMT - Quebrada",
      sensorLocation: const LatLng(-12.155375, -76.923746),
      redZone: [
        const LatLng(-12.154000, -76.923000),
        const LatLng(-12.155375, -76.923746),
        const LatLng(-12.157000, -76.924500),
        const LatLng(-12.158500, -76.925000),
        const LatLng(-12.158000, -76.923000),
        const LatLng(-12.154500, -76.922000),
      ],
      orangeZone: [
        const LatLng(-12.153000, -76.921000),
        const LatLng(-12.156000, -76.922000),
        const LatLng(-12.159000, -76.926000),
        const LatLng(-12.160000, -76.920000),
        const LatLng(-12.153000, -76.919000),
      ],
      greenZone: [
        const LatLng(-12.152000, -76.925000),
        const LatLng(-12.152000, -76.927000),
        const LatLng(-12.154000, -76.927000),
        const LatLng(-12.154000, -76.925000),
      ],
    ),

    // ZONA 2: CHOSICA (Nueva)
    ApuZone(
      name: "Chosica - Río Rímac",
      sensorLocation: const LatLng(-11.942000, -76.702000), // Centro Chosica
      redZone: [ // Cauce del río (Peligro)
        const LatLng(-11.938000, -76.698000),
        const LatLng(-11.942000, -76.702000),
        const LatLng(-11.945000, -76.705000),
        const LatLng(-11.944000, -76.706000),
        const LatLng(-11.941000, -76.703000),
        const LatLng(-11.937000, -76.699000),
      ],
      orangeZone: [ // Ribera (Riesgo Medio)
        const LatLng(-11.936000, -76.697000),
        const LatLng(-11.946000, -76.707000),
        const LatLng(-11.948000, -76.704000),
        const LatLng(-11.938000, -76.695000),
      ],
      greenZone: [ // Plaza / Zona Alta (Seguro)
        const LatLng(-11.940000, -76.708000),
        const LatLng(-11.940000, -76.710000),
        const LatLng(-11.938000, -76.710000),
        const LatLng(-11.938000, -76.708000),
      ],
    ),
  ];
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();

    // Si hay un foco inicial (desde historial), moverse allí tras construir
    if (widget.focusLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(widget.focusLocation!, 16.5);
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() => _myPosition = LatLng(position.latitude, position.longitude));
    } catch (e) { debugPrint("Error GPS: $e"); }
  }

  void _goToMyLocation() {
    if (_myPosition != null) {
      _mapController.move(_myPosition!, 16.0);
    } else {
      _getCurrentLocation();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Obteniendo ubicación...")));
    }
  }

  // --- FUNCIÓN NUEVA: ALEJAR Y VER TODOS LOS SENSORES ---
  void _fitAllMarkers() {
    if (_allZones.isEmpty) return;

    // 1. Recolectamos todas las coordenadas de los sensores
    List<LatLng> points = _allZones.map((z) => z.sensorLocation).toList();

    // 2. Calculamos los límites (Bounds) que encierran esos puntos
    LatLngBounds bounds = LatLngBounds.fromPoints(points);

    // 3. Ajustamos la cámara con un margen (padding) para que no queden pegados a los bordes
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(80),
      ),
    );
  }

  // --- FUNCIÓN DE BÚSQUEDA ---
  Future<void> _searchPlaces(String query) async {
    if (query.length < 3) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5&addressdetails=1&countrycodes=pe');
      final response = await http.get(url, headers: {'User-Agent': 'com.apuwaqay.app'});
      if (response.statusCode == 200) {
        setState(() => _searchResults = json.decode(response.body));
      }
    } catch (e) {
      debugPrint("Error búsqueda: $e");
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // -----------------------------------------------------------
          // 1. EL MAPA
          // -----------------------------------------------------------
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              // Si venimos del historial, centramos ahí. Si no, en el primer sensor.
              initialCenter: widget.focusLocation ?? _allZones[0].sensorLocation,
              initialZoom: widget.focusLocation != null ? 16.5 : 15.0,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              // A. Mapa Base
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.apuwaqay.app',
              ),

              // B. Capa de Zonas (Polígonos de Riesgo)
              if (_showZones)
                PolygonLayer(
                  polygons: [
                    // Recorremos TODAS las zonas registradas en _allZones
                    for (var zone in _allZones) ...[
                      // Zona Roja
                      Polygon(
                        points: zone.redZone,
                        color: Colors.red.withOpacity(0.4),
                        borderStrokeWidth: 2,
                        borderColor: Colors.red,
                        isFilled: true,
                      ),
                      // Zona Naranja
                      Polygon(
                        points: zone.orangeZone,
                        color: Colors.orange.withOpacity(0.3),
                        borderStrokeWidth: 2,
                        borderColor: Colors.orange,
                        isFilled: true,
                      ),
                      // Zona Verde
                      Polygon(
                        points: zone.greenZone,
                        color: Colors.green.withOpacity(0.4),
                        borderStrokeWidth: 2,
                        borderColor: Colors.green,
                        isFilled: true,
                      ),
                    ]
                  ],
                ),

              // C. Capa de Marcadores
              MarkerLayer(
                markers: [
                  // --- MARCADORES DE APU WAQAY (Interactivos) ---
                  for (var zone in _allZones)
                    Marker(
                      point: zone.sensorLocation,
                      width: 60,
                      height: 60,
                      child: GestureDetector(
                        onTap: () {
                          // AL TOCAR: Acercar cámara a este sensor
                          _mapController.move(zone.sensorLocation, 16.5);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Monitoreando: ${zone.name}"),
                              duration: const Duration(milliseconds: 1000),
                              backgroundColor: const Color(0xFFCF0A2C),
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Image.asset('assets/images/logo.png', width: 40, height: 40),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey),
                                  boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black26)]
                              ),
                              child: const Text(
                                "Apu Waqay",
                                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),

                  // --- MI UBICACIÓN ---
                  if (_myPosition != null)
                    Marker(
                      point: _myPosition!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                    ),

                  // --- MARCADOR DE EVENTO HISTÓRICO ---
                  if (widget.focusLocation != null)
                    Marker(
                      point: widget.focusLocation!,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_on, color: Colors.purple, size: 50),
                    ),
                ],
              ),
            ],
          ),

          // -----------------------------------------------------------
          // 2. BARRA SUPERIOR (Buscador + Toggle Capas)
          // -----------------------------------------------------------
          Positioned(
            top: 40,
            left: 15,
            right: 15,
            child: Column(
              children: [
                Row(
                  children: [
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
                    CircleAvatar(
                      backgroundColor: _showZones ? Colors.blue : Colors.white,
                      child: IconButton(
                        icon: Icon(Icons.layers, color: _showZones ? Colors.white : Colors.black),
                        onPressed: () => setState(() => _showZones = !_showZones),
                        tooltip: "Mostrar/Ocultar Riesgos",
                      ),
                    ),
                  ],
                ),
                // Resultados de Búsqueda
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
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
                            final lat = double.parse(place['lat']);
                            final lon = double.parse(place['lon']);
                            _mapController.move(LatLng(lat, lon), 16.0);
                            setState(() {
                              _searchResults = [];
                              _searchController.clear();
                            });
                            FocusScope.of(context).unfocus();
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // -----------------------------------------------------------
          // 3. LEYENDA FLOTANTE
          // -----------------------------------------------------------
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
                      const Text("Sensor Activo", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // -----------------------------------------------------------
          // 4. BOTONES FLOTANTES (Ver Todo + Mi Ubicación)
          // -----------------------------------------------------------
          Positioned(
            bottom: 30,
            right: 20,
            child: Column(
              children: [
                // Botón VER TODOS
                FloatingActionButton.small(
                  heroTag: "btn_fit_all",
                  onPressed: _fitAllMarkers,
                  backgroundColor: Colors.white,
                  tooltip: "Ver todos los sensores",
                  child: const Icon(Icons.grid_view, color: Colors.black87),
                ),
                const SizedBox(height: 10),

                // Botón MI UBICACIÓN
                FloatingActionButton(
                  heroTag: "btn_my_loc",
                  onPressed: _goToMyLocation,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para items de la leyenda
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
