import 'package:flutter/material.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/auth/login_screen.dart'; // <--- IMPORT NUEVO
import 'presentation/screens/home/home_layout.dart';
import 'presentation/screens/map/map_screen.dart';
import 'presentation/screens/settings/edit_sos_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/history/history_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login'; // <--- RUTA NUEVA
  static const String home = '/home';
  static const String map = '/map';
  static const String editSos = '/edit_sos'; // Nueva ruta
  static const String settings = '/settings'; // Nueva ruta
  static const String history = '/history';

  static Map<String, WidgetBuilder> get routes => {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(), // <--- REGISTRO NUEVO
    home: (context) => const HomeLayout(),
    map: (context) => const MapScreen(),
    editSos: (context) => const EditSosScreen(), // Pantalla nueva
    settings: (context) => const SettingsScreen(), // Pantalla nueva
    history: (context) => const HistoryScreen(),
  };
}