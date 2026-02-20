import 'package:flutter/material.dart';
import 'app_routes.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'data/services/global_alert_service.dart';
/*
void main() {
  runApp(const ApuWaqayApp());
}
*/


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar credenciales ocultas
  await dotenv.load(fileName: ".env");

  // INICIAR EL VIGILANTE EN SEGUNDO PLANO
  // Esto asegura que la app esté monitoreando incluso si el usuario minimiza la aplicación
  await GlobalAlertService().init();

  runApp(const ApuWaqayApp());
}

class ApuWaqayApp extends StatelessWidget {
  const ApuWaqayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apu Waqay',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFCF0A2C),
          primary: const Color(0xFFCF0A2C),
          secondary: Colors.amber,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),


 //     initialRoute: AppRoutes.splash,
      initialRoute: AppRoutes.login,
      routes: AppRoutes.routes,
    );
  }
}