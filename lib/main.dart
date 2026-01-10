import 'package:flutter/material.dart';
import 'app_routes.dart'; // Importamos el archivo de rutas que acabas de crear

void main() {
  runApp(const ApuWaqayApp());
}

class ApuWaqayApp extends StatelessWidget {
  const ApuWaqayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apu Waqay',
      debugShowCheckedModeBanner: false,

      // TEMA: Aquí definimos los colores de Huawei una sola vez
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFCF0A2C), // Rojo Huawei
          primary: const Color(0xFFCF0A2C),
          secondary: Colors.amber, // Para alertas
        ),
        useMaterial3: true,
        fontFamily: 'Roboto', // Fuente estándar limpia
      ),

      // NAVEGACIÓN: Usamos el sistema de rutas
      initialRoute: AppRoutes.splash, // La app arranca aquí
      routes: AppRoutes.routes,       // Cargamos el mapa de rutas
    );
  }
}