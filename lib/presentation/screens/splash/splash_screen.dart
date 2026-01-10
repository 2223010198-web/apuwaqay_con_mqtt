import 'package:flutter/material.dart';
import '../../../app_routes.dart'; // Para poder navegar

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  // Función para esperar y navegar
  _navigateToHome() async {
    // 1. Esperamos 2 segundos (Simulando carga o validación de sensores)
    await Future.delayed(const Duration(seconds: 2));

    // 2. Verificamos si la pantalla sigue montada (buena práctica)
    if (!mounted) return;

    // 3. Navegamos al Home y BORRAMOS el historial (para que no puedan volver al logo)
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fondo degradado sutil para que se vea moderno
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFFFF0F0)], // Blanco a Rojo muy pálido
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // TU LOGO AQUÍ
              Image.asset(
                'assets/images/logo.png',
                width: 180, // Tamaño del logo
                height: 180,
              ),
              const SizedBox(height: 20),

              // Texto de carga
              const CircularProgressIndicator(
                color: Color(0xFFCF0A2C), // Rojo Huawei
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              const Text(
                "Inicializando Sensores...",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}