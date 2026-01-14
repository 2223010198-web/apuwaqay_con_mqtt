import 'package:flutter/material.dart';
import 'dashboard_screen.dart'; // Importamos el dashboard
import '../map/map_screen.dart'; // Importamos el mapa
import '../history/history_screen.dart';

class HomeLayout extends StatefulWidget {
  const HomeLayout({super.key});

  @override
  State<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends State<HomeLayout> {
  int _selectedIndex = 0; // Controla qué pestaña está activa (0, 1 o 2)

  // Lista de pantallas que se mostrarán
  final List<Widget> _pages = [
    const DashboardScreen(), // 0: Monitor
    const MapScreen(),       // 1: Mapa
    const HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // El cuerpo cambia según la pestaña seleccionada
      body: _pages[_selectedIndex],

      // BARRA DE NAVEGACIÓN INFERIOR
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
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