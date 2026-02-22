import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_routes.dart';
import 'firebase_options.dart';
import 'data/services/global_alert_service.dart';
import 'data/services/mqtt_service.dart';

Future<void> main() async {
  // 1. Asegurar la inicialización de los bindings de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Cargar variables de entorno
  await dotenv.load(fileName: ".env");

  // 3. Inicializamos Firebase en el hilo principal de forma segura
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  // 4. Inicializar alertas globales
  await GlobalAlertService().init();

  // 🔥 FIX 1: Arrancar la app PRIMERO para destruir el Splash Screen instantáneamente
  runApp(const ApuWaqayApp());

  // 🔥 FIX 2: Iniciar el servicio de fondo SIN AWAIT en el hilo principal,
  // para que no congele el pintado inicial de la pantalla.
  _iniciarFondoDeFormaSegura();
}

// Función auxiliar para aislar el arranque del servicio Inmortal
Future<void> _iniciarFondoDeFormaSegura() async {
  try {
    await initializeBackgroundService();
  } catch (e) {
    debugPrint("⚠️ Error al iniciar el Background Service: $e");
  }
}

// ==========================================================
// CONFIGURACIÓN DEL SERVICIO EN SEGUNDO PLANO (BACKGROUND)
// ==========================================================
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'apu_waqay_service',
    'Apu Waqay - Monitoreo Activo',
    description: 'Vigilando actividad de sensores comunales 24/7',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Aseguramos la creación del canal de notificaciones en Android
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStartBackground,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'apu_waqay_service',
      initialNotificationTitle: 'Apu Waqay',
      initialNotificationContent: 'Monitoreo de desastres activo',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStartBackground,
      onBackground: (ServiceInstance service) => true,
    ),
  );

  service.startService();
}

// --- EL HILO DE PROCESAMIENTO INVISIBLE (ISOLATE) ---
// IMPORTANTE: @pragma le dice al compilador que mantenga esta función viva
@pragma('vm:entry-point')
void onStartBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  // CRÍTICO: Recargar variables de entorno en este nuevo Isolate (hilo separado)
  await dotenv.load(fileName: ".env");

  // 🔥 FIX 3: Evitar que Firebase colapse por inicializarse dos veces en el Isolate
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  debugPrint("🛡️ [BACKGROUND ISOLATE] Inicializando monitoreo en segundo plano.");

  // Instanciamos y conectamos MQTT de forma independiente al Dashboard
  final mqttService = MqttService();
  await mqttService.connect();
}

// ==========================================================
// APLICACIÓN PRINCIPAL (UI)
// ==========================================================
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

      initialRoute: AppRoutes.login,
      routes: AppRoutes.routes,
    );
  }
}