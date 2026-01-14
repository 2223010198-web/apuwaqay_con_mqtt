import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart'; // Necesario para manejar las coordenadas
import 'dashboard_screen.dart'; // Importamos el dashboard
import '../map/map_screen.dart'; // Importamos el mapa
import '../history/history_screen.dart'; // Importamos el historial

class HomeLayout extends StatefulWidget {
  const HomeLayout({super.key});

  @override
  State<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends State<HomeLayout> {
  int _selectedIndex = 0; // Controla qué pestaña está activa (0, 1 o 2)
  LatLng? _selectedMapLocation; // Variable para guardar la coordenada destino desde el historial

  // Función que llama el Historial para cambiar de pestaña al Mapa
  void _goToMapTab(LatLng location) {
    setState(() {
      _selectedMapLocation = location; // Guardamos la coordenada del huayco
      _selectedIndex = 1; // Cambiamos a la pestaña del Mapa (índice 1)
    });
  }

  @override
  Widget build(BuildContext context) {
    // Definimos las páginas aquí dentro para poder pasarles los argumentos y funciones actualizadas
    final List<Widget> pages = [
      const DashboardScreen(), // 0: Monitor

      // 1: Mapa (Recibe la ubicación si viene del historial para centrarse allí)
      MapScreen(focusLocation: _selectedMapLocation),

      // 2: Historial (Recibe la función para poder cambiar al mapa)
      HistoryScreen(onMapRequest: _goToMapTab),
    ];

    return Scaffold(
      // El cuerpo cambia según la pestaña seleccionada
      body: pages[_selectedIndex],

      // BARRA DE NAVEGACIÓN INFERIOR
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;

            // Si el usuario toca el botón Mapa manualmente, podemos limpiar el foco
            // para que no se quede "pegado" en el evento anterior (Opcional)
            if (index == 1) {
              // _selectedMapLocation = null;
            }
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Monitor',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa Riesgo',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historial',
          ),
        ],
      ),
    );
  }
}