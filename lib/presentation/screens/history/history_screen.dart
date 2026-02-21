import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';

// --- SERVICIOS Y MODELOS ---
import '../../../data/services/firebase_service.dart';
import '../../../domain/models/huayco_event.dart';

// --- COMPONENTES Y PANTALLAS ---
import '../../widgets/side_menu.dart';
import '../../widgets/event_card.dart';
import 'event_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  final Function(LatLng)? onMapRequest;

  const HistoryScreen({super.key, this.onMapRequest});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // --- LÓGICA Y ESTADO INTACTOS ---
  final FirebaseService _firebaseService = FirebaseService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  HuaycoEvent? _selectedEvent;

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo abrir $urlString')));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedEvent == null,
      onPopInvoked: (didPop) {
        if (!didPop && _selectedEvent != null) {
          setState(() => _selectedEvent = null); // Regresa a la lista
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.grey[50],
        drawer: const SideMenu(),

        // MAGIA AQUÍ: Mostramos los detalles o la lista general
        body: _selectedEvent != null
            ? EventDetailScreen(
          event: _selectedEvent!,
          onMapRequest: widget.onMapRequest,
          onBack: () => setState(() => _selectedEvent = null), // Cierra los detalles
        )
            : _buildMainContent(),
      ),
    );
  }

  // --- WIDGETS DE DISEÑO (UI/UX) ---
  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCustomHeader(),
          _buildEmergencySection(),
          const SizedBox(height: 20),
          _buildSearchBar(),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text("Registro de Eventos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          _buildFirebaseList(), // Aquí se inyecta Firebase
        ],
      ),
    );
  }


  Widget _buildCustomHeader() {
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10, // Respeta el notch del celular
          left: 10, right: 20, bottom: 20
      ),
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
    );
  }

  Widget _buildEmergencySection() {
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: const Color(0xFFCF0A2C), // Rojo Apu Waqay
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            boxShadow: [
              BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
            ]
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Canales Oficiales", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Usamos HistoryContactButton para evitar el choque de nombres anterior
                    HistoryContactButton(icon: Icons.local_police, label: "Policía", number: "105", onTap: () => _launchURL("tel:105")),
                    HistoryContactButton(icon: Icons.fire_truck, label: "Bomberos", number: "116", onTap: () => _launchURL("tel:116")),
                    HistoryContactButton(icon: Icons.support_agent, label: "INDECI", number: "115", onTap: () => _launchURL("tel:115")),
                    HistoryContactButton(icon: Icons.language, label: "Web", number: "Info", onTap: () => _launchURL("https://www.gob.pe/indeci")),
                  ]
              ),
            ]
        )
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: "Buscar por lugar o título...",
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ""); })
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  // --- CONEXIÓN DE DATOS A FIREBASE (LÓGICA INTACTA) ---
  Widget _buildFirebaseList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: StreamBuilder<List<HuaycoEvent>>(
        stream: _firebaseService.getHistorialEventos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: Colors.red)),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text("Error de conexión:\n${snapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            ));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text("No hay eventos recientes.", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            ));
          }

          // Filtrado
          List<HuaycoEvent> eventos = snapshot.data!;
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            eventos = eventos.where((e) => e.titulo.toLowerCase().contains(q) || e.lugar.toLowerCase().contains(q)).toList();
          }

          if (eventos.isEmpty) {
            return Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text("Sin resultados para '$_searchQuery'", style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            ));
          }

          return ListView.builder(
            shrinkWrap: true, // Importante para que ListView conviva dentro de SingleChildScrollView
            physics: const NeverScrollableScrollPhysics(),
            itemCount: eventos.length,
            itemBuilder: (context, index) {
              final evento = eventos[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 15), // Separación elegante entre Cards
                child: EventCard(
                  event: evento,
                  onTap: () {
                    // Actualizamos el estado para mostrar los detalles en la misma pantalla
                    setState(() {
                      _selectedEvent = evento;
                    });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- WIDGET PARA BOTONES DE EMERGENCIA RÁPIDOS ---
// Mantenemos el estilo limpio que solicitaste (botón blanco sobre fondo rojo)
class HistoryContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String number;
  final VoidCallback onTap;

  const HistoryContactButton({
    super.key,
    required this.icon,
    required this.label,
    required this.number,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 75, // Tamaño uniforme
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.red[900], size: 28),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              number,
              style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}