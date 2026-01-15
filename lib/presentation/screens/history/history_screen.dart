import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';

// --- IMPORTS DE MODELOS Y COMPONENTES ---
import '../../../domain/models/huayco_event.dart';      // Modelo de datos
import '../../widgets/side_menu.dart';               // Menú lateral reutilizable
import '../../widgets/emergency_button.dart';        // Botones de emergencia
import '../../widgets/event_card.dart';              // Tarjeta de evento

class HistoryScreen extends StatefulWidget {
  final Function(LatLng)? onMapRequest;

  const HistoryScreen({super.key, this.onMapRequest});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Clave para controlar el Scaffold y abrir el Drawer manualmente
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _searchController = TextEditingController();

  // Variable para controlar si mostramos la lista o el detalle
  HuaycoEvent? _selectedEvent;

  // --- DATOS SIMULADOS (Usando el modelo importado) ---
  final List<HuaycoEvent> _allEvents = [
    HuaycoEvent(
      title: "Desborde Quebrada del Toro",
      date: "12 Mar 2023",
      location: "Camaná, Arequipa",
      severity: "Alta",
      description: "Activación de quebrada afectando 500 viviendas y la carretera principal. Se requiere maquinaria pesada para limpieza.",
      source: "INDECI",
      coords: const LatLng(-16.625, -72.711),
      images: [
        "https://portal.indeci.gob.pe/wp-content/uploads/2023/03/WhatsApp-Image-2023-03-12-at-10.35.15-AM.jpeg",
        "https://peru21.pe/resizer/v2/LQP5J5ZTZNHYRN6F6F6F6F6F6F.jpg?auth=6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f&width=980&height=528&quality=75&smart=true",
      ],
    ),
    HuaycoEvent(
      title: "Huayco en Chosica",
      date: "05 Feb 2023",
      location: "Chosica, Lima",
      severity: "Media",
      description: "Bloqueo de la carretera central por deslizamiento de lodo y piedras en el km 40.",
      source: "IGP",
      coords: const LatLng(-11.936, -76.692),
      images: [
        "https://elperuano.pe/fotografia/thumbnail/2023/02/05/000213697M.jpg",
      ],
    ),
    HuaycoEvent(
      title: "Deslizamiento en Jicamarca",
      date: "15 Mar 2017",
      location: "San Juan de Lurigancho",
      severity: "Alta",
      description: "El fenómeno 'El Niño Costero' provocó uno de los desastres más grandes en la zona de Cajamarquilla.",
      source: "Noticias",
      coords: const LatLng(-11.950, -76.980),
      images: [], // Sin imágenes
    ),
    HuaycoEvent(
      title: "Alerta Río Rímac",
      date: "10 Ene 2024",
      location: "Chaclacayo",
      severity: "Baja",
      description: "Aumento de caudal preventivo por lluvias en la sierra central. No hubo desbordes mayores.",
      source: "SENAMHI",
      coords: const LatLng(-11.975, -76.765),
      images: [],
    ),
  ];

  List<HuaycoEvent> _filteredEvents = [];

  @override
  void initState() {
    super.initState();
    _filteredEvents = _allEvents;
  }

  void _filterEvents(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredEvents = _allEvents;
      } else {
        _filteredEvents = _allEvents
            .where((event) =>
        event.location.toLowerCase().contains(query.toLowerCase()) ||
            event.title.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) debugPrint("No se pudo abrir $url");
  }

  @override
  Widget build(BuildContext context) {
    // PopScope maneja el botón "Atrás" físico de Android
    return PopScope(
      canPop: _selectedEvent == null,
      onPopInvoked: (didPop) {
        if (_selectedEvent != null) {
          setState(() => _selectedEvent = null);
        }
      },
      child: Scaffold(
        key: _scaffoldKey, // Asignamos la llave para controlar el Drawer
        backgroundColor: Colors.grey[50],

        // MENÚ LATERAL IMPORTADO
        drawer: const SideMenu(),

        // RENDERIZADO CONDICIONAL: Lista o Detalle
        body: _selectedEvent != null ? _buildDetailView() : _buildListView(),
      ),
    );
  }

  // --- VISTA 1: LISTA DE EVENTOS ---
  Widget _buildListView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header personalizado
          Container(
            padding: const EdgeInsets.only(top: 40, left: 10, right: 20, bottom: 20),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black87),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                const SizedBox(width: 5),
                const Text("Historial y Recursos", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                const Icon(Icons.history_edu, color: Colors.blueGrey),
              ],
            ),
          ),

          _buildEmergencySection(),

          const SizedBox(height: 20),

          // Buscador
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: TextField(
                controller: _searchController,
                onChanged: _filterEvents,
                decoration: const InputDecoration(
                  hintText: "Buscar por lugar...",
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text("Registro de Eventos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          const SizedBox(height: 10),

          // Lista usando el componente reutilizable EventCard
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredEvents.length,
            itemBuilder: (context, index) {
              return EventCard(
                event: _filteredEvents[index],
                onTap: () {
                  setState(() {
                    _selectedEvent = _filteredEvents[index];
                  });
                },
              );
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // --- VISTA 2: DETALLE DEL EVENTO ---
  Widget _buildDetailView() {
    final event = _selectedEvent!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header detalle con botón volver
          Container(
            padding: const EdgeInsets.only(top: 40, left: 10, right: 20, bottom: 10),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => setState(() => _selectedEvent = null),
                ),
                Expanded(child: Text(event.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),

          // Carrusel de Imágenes
          SizedBox(
            height: 250,
            child: event.images.isNotEmpty
                ? PageView.builder(
              itemCount: event.images.length,
              itemBuilder: (context, index) {
                return Image.network(
                  event.images[index],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[300], child: const Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                );
              },
            )
                : Container(
              color: Colors.grey[200],
              child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Image.asset('assets/images/logo.png', width: 60), const SizedBox(height: 10), const Text("Sin imágenes disponibles", style: TextStyle(color: Colors.grey))])),
            ),
          ),

          // Banner de Severidad
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: _getSeverityColor(event.severity).withOpacity(0.2),
            child: Center(child: Text("NIVEL DE SEVERIDAD: ${event.severity.toUpperCase()}", style: TextStyle(color: _getSeverityColor(event.severity), fontWeight: FontWeight.bold, letterSpacing: 1.5))),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(icon: Icons.calendar_today, label: "Fecha:", value: event.date),
                _DetailRow(icon: Icons.location_on, label: "Ubicación:", value: event.location),
                _DetailRow(icon: Icons.source, label: "Fuente:", value: event.source),

                const SizedBox(height: 20),
                const Text("Descripción del Evento", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(event.description, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87), textAlign: TextAlign.justify),

                const SizedBox(height: 30),

                // Botón Ver en Mapa
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.map),
                    label: const Text("VER UBICACIÓN EN EL MAPA"),
                    onPressed: () {
                      if (widget.onMapRequest != null) {
                        widget.onMapRequest!(event.coords);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mapa no disponible")));
                      }
                    },
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SECCIÓN DE EMERGENCIA (Usa widgets importados) ---
  Widget _buildEmergencySection() {
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFFCF0A2C), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Canales Oficiales", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                EmergencyButton(icon: Icons.local_police, label: "Policía", number: "105", onTap: () => _launchURL("tel:105")),
                EmergencyButton(icon: Icons.fire_truck, label: "Bomberos", number: "116", onTap: () => _launchURL("tel:116")),
                EmergencyButton(icon: Icons.support_agent, label: "INDECI", number: "115", onTap: () => _launchURL("tel:115")),
                EmergencyButton(icon: Icons.language, label: "Web", number: "Info", onTap: () => _launchURL("https://www.gob.pe/indeci")),
              ]),
            ]));
  }

  Color _getSeverityColor(String severity) {
    switch (severity) { case 'Alta': return Colors.red; case 'Media': return Colors.orange; default: return Colors.green; }
  }
}

// --- WIDGET LOCAL ---
// Mantenemos este pequeño widget aquí porque es muy específico de la vista de detalle
class _DetailRow extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 20, color: Colors.grey), const SizedBox(width: 10), SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)))]));
  }
}