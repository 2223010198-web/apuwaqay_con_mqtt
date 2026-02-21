import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// --- SERVICIOS Y MODELOS ---
import '../../../data/services/firebase_service.dart';
import '../../../domain/models/sensor_zone.dart';

class MapScreen extends StatefulWidget {
  final LatLng? initialCoords;
  const MapScreen({super.key, this.initialCoords});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  // Variables de UI y estado
  bool _showZones = true;
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  LatLng? _myPosition;

  // Guardaremos la lista de sensores obtenida de Firebase para la función _fitAllMarkers
  List<SensorZone> _currentZones = [];

  final LatLng _defaultCenter = const LatLng(-11.936, -76.692);

  @override
  void initState() {
    super.initState();

    if (widget.initialCoords != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(widget.initialCoords!, 16.5);
      });
    } else {
      _getCurrentLocation();
    }
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCoords != null && widget.initialCoords != oldWidget.initialCoords) {
      _mapController.move(widget.initialCoords!, 16.5);
    }
  }

  // --- LÓGICA DE UBICACIÓN Y MAPA ---
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _myPosition = LatLng(position.latitude, position.longitude));
        if (widget.initialCoords == null) {
          _mapController.move(_myPosition!, 15.0);
        }
      }
    } catch (e) {
      debugPrint("Error GPS: $e");
    }
  }

  void _goToMyLocation() {
    if (_myPosition != null) {
      _mapController.move(_myPosition!, 16.0);
    } else {
      _getCurrentLocation();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Obteniendo ubicación...")));
    }
  }

  void _fitAllMarkers() {
    if (_currentZones.isEmpty) return;

    // Filtramos solo los sensores que tengan coordenadas válidas
    List<LatLng> points = _currentZones
        .where((z) => z.sensorCoords != null)
        .map((z) => z.sensorCoords!)
        .toList();

    if (points.isEmpty) return;

    LatLngBounds bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)));
  }

  // --- LÓGICA DE BÚSQUEDA WEB (OSM) ---
  Future<void> _searchPlaces(String query) async {
    if (query.length < 3) { setState(() => _searchResults = []); return; }
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5&addressdetails=1&countrycodes=pe');
      final response = await http.get(url, headers: {'User-Agent': 'com.apuwaqay.app'});
      if (response.statusCode == 200 && mounted) {
        setState(() => _searchResults = json.decode(response.body));
      }
    } catch (e) {
      debugPrint("Error búsqueda: $e");
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }
  // --- CONSTRUCCIÓN DE LA INTERFAZ ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
            children: [

        // --- 1. CAPA INFERIOR: EL MAPA Y LOS DATOS DE FIREBASE ---
        StreamBuilder<List<SensorZone>>(
        stream: _firebaseService.getZonasYSensores(),
        builder: (context, snapshot) {

          // Actualizamos nuestra lista local de sensores silenciosamente
          // para que el botón de "Hacer zoom a todos los sensores" funcione.
          if (snapshot.hasData) {
            _currentZones = snapshot.data!;
          }

          // Preparar listas de dibujo
          List<Polygon> polygons = [];
          List<Marker> markers = [];

          if (snapshot.hasData) {
            for (var zone in snapshot.data!) {

              // --- DIBUJAR POLÍGONOS (Solo si _showZones es true) ---
              if (_showZones) {
                if (zone.zonaAlta.isNotEmpty) {
                  polygons.add(Polygon(points: zone.zonaAlta, color: Colors.red.withOpacity(0.4), borderStrokeWidth: 2, borderColor: Colors.red, isFilled: true));
                }
                if (zone.zonaMedia.isNotEmpty) {
                  polygons.add(Polygon(points: zone.zonaMedia, color: Colors.orange.withOpacity(0.3), borderStrokeWidth: 2, borderColor: Colors.orange, isFilled: true));
                }
                if (zone.zonaSegura.isNotEmpty) {
                  polygons.add(Polygon(points: zone.zonaSegura, color: Colors.green.withOpacity(0.4), borderStrokeWidth: 2, borderColor: Colors.green, isFilled: true));
                }
              }

              // --- DIBUJAR SENSORES ---
              if (zone.sensorCoords != null) {
                markers.add(
                    Marker(
                      point: zone.sensorCoords!,
                      width: 60, height: 60,
                      child: GestureDetector(
                        onTap: () {
                          _mapController.move(zone.sensorCoords!, 16.5);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Monitoreando Zona: ${zone.id}"), // Usamos el ID de Firebase como nombre
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
                    )
                );
              }
            }
          }

          // --- MARCADOR DE MI UBICACIÓN (GPS) ---
          if (_myPosition != null) {
            markers.add(
                Marker(
                  point: _myPosition!,
                  width: 40, height: 40,
                  child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                )
            );
          }

          // --- MARCADOR DE EVENTO HISTÓRICO (Si venimos de la vista Historial) ---
          if (widget.initialCoords != null) {
            markers.add(
                Marker(
                  point: widget.initialCoords!,
                  width: 60, height: 60,
                  child: const Column(
                    children: [
                      Icon(Icons.location_on, color: Colors.purple, size: 40),
                      Text("Evento", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.purple, backgroundColor: Colors.white)),
                    ],
                  ),
                )
            );
          }

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialCoords ?? _defaultCenter,
              initialZoom: widget.initialCoords != null ? 16.5 : 15.0,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.apuwaqay.app',
              ),
              if (_showZones) PolygonLayer(polygons: polygons),
              MarkerLayer(markers: markers),
            ],
          );
        }
    ),

              // --- 2. UI FLOTANTE: BUSCADOR WEB Y BOTÓN CAPAS ---
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
                                hintText: "Buscar zona en mapa web...",
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

                    // Resultados de búsqueda
                    if (_searchResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
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

              // --- 3. UI FLOTANTE: LEYENDA (IZQUIERDA) ---
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

              // --- 4. UI FLOTANTE: BOTONES DE ACCIÓN (DERECHA) ---
              Positioned(
                bottom: 30,
                right: 20,
                child: Column(
                  children: [
                    // Botón: Ver todos los sensores
                    FloatingActionButton.small(
                      heroTag: "btn_fit_all",
                      onPressed: _fitAllMarkers, // <--- Ahora usa los datos de Firebase
                      backgroundColor: Colors.white,
                      tooltip: "Ver todos los sensores",
                      child: const Icon(Icons.grid_view, color: Colors.black87),
                    ),
                    const SizedBox(height: 10),

                    // Botón: Mi ubicación GPS
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

  // --- WIDGET AUXILIAR PARA LA LEYENDA ---
  Widget _legendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
              width: 12, height: 12,
              decoration: BoxDecoration(color: color.withOpacity(0.6), border: Border.all(color: color))
          ),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}