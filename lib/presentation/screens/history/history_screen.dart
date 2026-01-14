import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Para abrir webs/teléfono
import 'package:latlong2/latlong.dart'; // Para pasar coordenadas al mapa
import '../../../app_routes.dart';

// Modelo de datos simple para un evento histórico
class HuaycoEvent {
  final String title;
  final String date;
  final String location;
  final String severity; // 'Alta', 'Media', 'Baja'
  final String description;
  final String source;
  final LatLng coords;

  HuaycoEvent({
    required this.title,
    required this.date,
    required this.location,
    required this.severity,
    required this.description,
    required this.source,
    required this.coords,
  });
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  // --- BASE DE DATOS SIMULADA (HISTORIAL) ---
  final List<HuaycoEvent> _allEvents = [
    HuaycoEvent(
      title: "Desborde Quebrada del Toro",
      date: "12 Mar 2023",
      location: "Camaná, Arequipa",
      severity: "Alta",
      description: "Activación de quebrada afectando 500 viviendas y carretera principal.",
      source: "INDECI",
      coords: const LatLng(-16.625, -72.711),
    ),
    HuaycoEvent(
      title: "Huayco en Chosica",
      date: "05 Feb 2023",
      location: "Chosica, Lima",
      severity: "Media",
      description: "Bloqueo de la carretera central por deslizamiento de lodo.",
      source: "IGP",
      coords: const LatLng(-11.936, -76.692),
    ),
    HuaycoEvent(
      title: "Deslizamiento en Jicamarca",
      date: "15 Mar 2017",
      location: "San Juan de Lurigancho",
      severity: "Alta",
      description: "El 'Niño Costero' provocó uno de los desastres más grandes en la zona.",
      source: "Noticias",
      coords: const LatLng(-11.950, -76.980),
    ),
    HuaycoEvent(
      title: "Alerta Río Rímac",
      date: "10 Ene 2024",
      location: "Chaclacayo",
      severity: "Baja",
      description: "Aumento de caudal preventivo. No hubo desbordes.",
      source: "SENAMHI",
      coords: const LatLng(-11.975, -76.765),
    ),
  ];

  List<HuaycoEvent> _filteredEvents = [];

  @override
  void initState() {
    super.initState();
    _filteredEvents = _allEvents; // Al inicio mostramos todo
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

  // Función para abrir URLs o Teléfonos
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      debugPrint("No se pudo abrir $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Historial y Recursos"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. SECCIÓN DE EMERGENCIA (CARRUSEL)
            _buildEmergencySection(),

            const SizedBox(height: 20),

            // 2. BUSCADOR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterEvents,
                  decoration: const InputDecoration(
                    hintText: "Buscar por lugar (ej: Chosica)...",
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3. TÍTULO DE LISTA
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Registro de Eventos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Icon(Icons.history, color: Colors.grey),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 4. LISTA DE TARJETAS
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), // El scroll lo hace el padre
              itemCount: _filteredEvents.length,
              itemBuilder: (context, index) {
                return _EventCard(event: _filteredEvents[index]);
              },
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // WIDGET: SECCIÓN DE EMERGENCIA
  Widget _buildEmergencySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFCF0A2C),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Canales Oficiales", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _EmergencyButton(
                icon: Icons.local_police,
                label: "Policía",
                number: "105",
                onTap: () => _launchURL("tel:105"),
              ),
              _EmergencyButton(
                icon: Icons.fire_truck,
                label: "Bomberos",
                number: "116",
                onTap: () => _launchURL("tel:116"),
              ),
              _EmergencyButton(
                icon: Icons.support_agent,
                label: "INDECI",
                number: "115",
                onTap: () => _launchURL("tel:115"),
              ),
              _EmergencyButton(
                icon: Icons.language,
                label: "Web",
                number: "Info",
                onTap: () => _launchURL("https://www.gob.pe/indeci"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// WIDGET: BOTÓN DE EMERGENCIA
class _EmergencyButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String number;
  final VoidCallback onTap;

  const _EmergencyButton({required this.icon, required this.label, required this.number, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// WIDGET: TARJETA DE EVENTO
class _EventCard extends StatelessWidget {
  final HuaycoEvent event;

  const _EventCard({required this.event});

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'Alta': return Colors.red;
      case 'Media': return Colors.orange;
      default: return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Cabecera: Severidad y Fecha
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _getSeverityColor(event.severity).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Severidad: ${event.severity}",
                  style: TextStyle(color: _getSeverityColor(event.severity), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Text(event.date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),

          const SizedBox(height: 10),

          // Título y Lugar
          Text(event.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(event.location, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),

          const SizedBox(height: 10),
          Text(event.description, style: const TextStyle(fontSize: 13, color: Colors.black87)),

          const SizedBox(height: 15),

          // Botones de Acción
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Fuente: ${event.source}", style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey)),

              ElevatedButton.icon(
                onPressed: () {
                  // AQUÍ CONECTAMOS CON TU MAPA
                  // Nota: Para que esto funcione perfecto, tu MapScreen debería aceptar argumentos
                  // Por ahora, simplemente abrimos el mapa genérico
                  Navigator.pushNamed(context, AppRoutes.map);

                  // *IDEA:* Podrías mostrar un SnackBar diciendo:
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Mostrando zona: ${event.location}"))
                  );
                },
                icon: const Icon(Icons.map, size: 16),
                label: const Text("Ver en Mapa"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[50],
                  foregroundColor: Colors.blue,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}