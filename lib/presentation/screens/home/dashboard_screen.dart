import 'dart:async'; // Para controlar el tiempo de vibración
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../app_routes.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  // VARIABLES DE ESTADO
  int alertLevel = 0; // 0=Seguro, 1=Precaución, 2=Peligro
  String userName = "Usuario";
  bool sosEnabled = true;
  bool autoSend = false;
  bool realTime = false;
  double vibrationIntensity = 0.0;
  String etaHuayco = "";

  // Variable para controlar si faltan permisos
  bool _missingPermissions = true;

  // Canal nativo SMS
  static const platform = MethodChannel('com.apuwaqay/sms');

  // Notificaciones
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // Control de Vibración
  Timer? _vibrationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    _initNotifications();
    _checkPermissionsStatus(); // Verificar permisos al iniciar

    // Pedir permisos iniciales al abrir (con leve retraso para no bloquear UI)
    Future.delayed(const Duration(seconds: 1), () {
      _requestAllPermissions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopVibration();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Verificar permisos cada vez que vuelve a la app
      _checkPermissionsStatus();
      if (alertLevel == 1) {
        _checkPermissionsForWarning();
      }
    }
  }

  // --- 1. CONFIGURACIÓN DE NOTIFICACIONES ---
  void _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
        'apu_waqay_alerts', 'Alertas de Huayco',
        channelDescription: 'Notificaciones críticas de seguridad',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker');

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(0, title, body, platformChannelSpecifics);
  }

  // --- 2. GESTIÓN DE PERMISOS ---

  // Función para VERIFICAR si falta algo (sin pedir, solo mirar)
  Future<void> _checkPermissionsStatus() async {
    bool loc = await Permission.location.isGranted;
    bool sms = await Permission.sms.isGranted;
    bool phone = await Permission.phone.isGranted;
    bool notif = await Permission.notification.isGranted;

    if (mounted) {
      setState(() {
        // Si falta CUALQUIERA de estos, activamos la bandera
        _missingPermissions = !(loc && sms && phone && notif);
      });
    }
  }

  Future<void> _requestAllPermissions() async {
    await [
      Permission.location,
      Permission.sms,
      Permission.phone,
      Permission.notification,
    ].request();

    // Volvemos a verificar el estado después de pedir
    _checkPermissionsStatus();
  }

  Future<void> _checkPermissionsForWarning() async {
    if (sosEnabled && alertLevel == 1) {
      if (_missingPermissions) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("⚠️ Precaución Activada"),
              content: const Text("Necesitamos permisos de SMS y Ubicación para protegerte."),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _requestAllPermissions();
                  },
                  child: const Text("Dar Permisos"),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  // Diálogo manual cuando presionan el triangulo amarillo
  void _showPermissionWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber, color: Colors.orange), SizedBox(width: 10), Text("Permisos Faltantes")]),
        content: const Text("Se debe dar permisos para notificar y recibir alertas, y enviar tu ubicación en caso de huayco."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _requestAllPermissions(); // Intenta pedir permisos de nuevo
              // Si están denegados permanentemente, abrimos ajustes
              openAppSettings();
            },
            child: const Text("SOLUCIONAR AHORA"),
          ),
        ],
      ),
    );
  }

  // --- 3. LÓGICA DE VIBRACIÓN ---
  void _startVibrationPattern({required bool isRedAlert}) {
    _stopVibration();

    int counter = 0;
    int maxDuration = isRedAlert ? 10 : 5;

    if (isRedAlert) {
      _triggerVibrate();
      _vibrationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        counter += 3;
        if (counter >= maxDuration) {
          _stopVibration();
        } else {
          _triggerVibrate();
        }
      });
    } else {
      _vibrationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        counter++;
        if (counter >= (maxDuration * 2)) {
          _stopVibration();
        } else {
          Vibrate.feedback(FeedbackType.warning);
        }
      });
    }
  }

  void _triggerVibrate() async {
    bool canVibrate = await Vibrate.canVibrate;
    if (canVibrate) {
      Vibrate.vibrateWithPauses([
        const Duration(milliseconds: 100),
        const Duration(milliseconds: 1000),
      ]);
    }
  }

  void _stopVibration() {
    if (_vibrationTimer != null) {
      _vibrationTimer!.cancel();
      _vibrationTimer = null;
    }
  }

  // --- 4. FUNCIONES AUXILIARES ---

  Color getStatusColor() {
    if (alertLevel == 0) return Colors.green;
    if (alertLevel == 1) return Colors.orange;
    return const Color(0xFFCF0A2C);
  }

  String getStatusText() {
    if (alertLevel == 0) return "ZONA SEGURA";
    if (alertLevel == 1) return "PRECAUCIÓN";
    return "¡PELIGRO DE HUAYCO!";
  }

  void _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? "Usuario";
      sosEnabled = prefs.getBool('sos_enabled') ?? true;
      autoSend = prefs.getBool('sos_auto_send') ?? false;
      realTime = prefs.getBool('sos_realtime') ?? false;
    });
  }

  // --- 5. SIMULACIÓN ---
  void _simulateChange() async {
    setState(() {
      alertLevel = (alertLevel + 1) % 3;

      vibrationIntensity = 0.0;
      etaHuayco = "";

      if (alertLevel == 0) {
        _stopVibration();
      } else if (alertLevel == 1) {
        vibrationIntensity = 3.5;
        etaHuayco = "Posible en 45 min";

        _showNotification("⚠️ ALERTA: Precaución", "Nivel del río subiendo. Mantente alerta.");
        _startVibrationPattern(isRedAlert: false);
        _showCautionDialog();
        _checkPermissionsForWarning();

      } else if (alertLevel == 2) {
        vibrationIntensity = 7.8;
        etaHuayco = "IMPACTO EN 15 MIN";

        _showNotification("🚨 PELIGRO: HUAYCO INMINENTE", "Evacúa inmediatamente a zonas altas.");
        _startVibrationPattern(isRedAlert: true);

        if (autoSend) _sendSOS(isAuto: true);
        _showEmergencyDialog();
      }
    });
  }

  // --- 6. ENVÍO SOS (NATIVO) ---
  Future<void> _sendSOS({bool isAuto = false}) async {
    if (!isAuto && alertLevel == 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sistema Seguro.")));
      return;
    }

    if (await Permission.sms.isDenied) await Permission.sms.request();
    if (await Permission.location.isDenied) await Permission.location.request();

    // Verificamos de nuevo para actualizar el icono amarillo
    _checkPermissionsStatus();

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (mounted && !isAuto) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enviando alerta nativa...")));
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      debugPrint("Error GPS: $e");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    String c1 = prefs.getString('sos_contact_1') ?? "";
    String c2 = prefs.getString('sos_contact_2') ?? "";
    List<String> recipients = ["992934043"];
    if (c1.isNotEmpty) recipients.add(c1);
    if (c2.isNotEmpty) recipients.add(c2);

    String mapsLink = "http://maps.google.com/?q=${position.latitude},${position.longitude}";
    String msg = "¡SOS HUAYCO! Soy $userName. UBICACION: $mapsLink";

    int successCount = 0;
    for (String number in recipients) {
      try {
        await platform.invokeMethod('sendDirectSMS', {"phone": number, "msg": msg});
        successCount++;
      } catch (e) {
        debugPrint("❌ Error nativo: $e");
      }
    }

    if (mounted && successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Alerta enviada a $successCount contactos."), backgroundColor: Colors.green),
      );
    }
  }

  // --- DIÁLOGOS ---
  void _showCautionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.orange[50],
        title: const Row(children: [Icon(Icons.warning_amber, color: Colors.orange), SizedBox(width: 10), Text("PRECAUCIÓN")]),
        content: const Text("Se ha detectado actividad inusual. Por favor, mantente atento a las notificaciones."),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              _stopVibration();
              Navigator.pop(context);
            },
            child: const Text("ACEPTAR", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red[50],
        title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 10), Text("¡ALERTA ROJA!")]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Huayco inminente. ETA: $etaHuayco."),
            const SizedBox(height: 10),
            if (autoSend)
              const Text("✅ Alerta enviada automáticamente.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))
            else
              const Text("⚠️ Presiona SOS para enviar alerta.", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              _stopVibration();
              Navigator.pop(context);
            },
            child: const Text("ENTENDIDO"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: getStatusColor()),
              accountName: Text(userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              accountEmail: const Text("Usuario Verificado"),
              currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, size: 40, color: Colors.black54)),
            ),
            ListTile(
              leading: const Icon(Icons.sos, color: Colors.red),
              title: const Text("Editar SOS"),
              subtitle: const Text("Contactos y Automatización"),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.pushNamed(context, AppRoutes.editSos);
                _loadUserData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Ajustes"),
              subtitle: const Text("Perfil y Dirección"),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.pushNamed(context, AppRoutes.settings);
                _loadUserData();
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text("Monitor Apu Waqay"),
        backgroundColor: getStatusColor(),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.bug_report), onPressed: _simulateChange, tooltip: "Simular Alerta"),
        ],
      ),

      // --- AQUÍ ESTÁ LA MAGIA DE LA UI ---
      // Usamos un Row para poner el icono de advertencia AL LADO del SOS
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end, // Alinear a la derecha como un FAB normal
        children: [
          // 1. ICONO DE ADVERTENCIA (Solo aparece si faltan permisos y el SOS está activo)
          if (_missingPermissions && sosEnabled) ...[
            FloatingActionButton.small(
              heroTag: "btn_warning", // Tag único para evitar error de Hero
              backgroundColor: Colors.yellow[700],
              onPressed: _showPermissionWarningDialog,
              child: const Icon(Icons.warning_amber, color: Colors.black, size: 28),
            ),
            const SizedBox(width: 15), // Espacio entre advertencia y SOS
          ],

          // 2. BOTÓN SOS ORIGINAL
          if (sosEnabled)
            FloatingActionButton.extended(
              heroTag: "btn_sos",
              onPressed: () => _sendSOS(isAuto: false),
              backgroundColor: alertLevel == 0 ? Colors.grey : Colors.red[900],
              icon: const Icon(Icons.sos, color: Colors.white, size: 30),
              label: Text(alertLevel == 0 ? "SOS (Inactivo)" : "SOS", style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),

      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: getStatusColor(),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
              boxShadow: [BoxShadow(color: getStatusColor().withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                Icon(alertLevel == 2 ? Icons.campaign : Icons.verified_user, size: 80, color: Colors.white),
                const SizedBox(height: 10),
                Text(getStatusText(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                if (alertLevel == 2)
                  Text("LLEGADA ESTIMADA: $etaHuayco", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.map),
              icon: const Icon(Icons.people_alt),
              label: const Text("Ver Ubicaciones Compartidas"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.white, foregroundColor: Colors.black87),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  _SensorCard(title: "Nivel Río", value: alertLevel == 2 ? "4.5 m" : "1.2 m", unit: "Metros", icon: Icons.waves, isCritical: alertLevel == 2),
                  _SensorCard(title: "Lluvia", value: alertLevel == 2 ? "120 mm" : "0 mm", unit: "Acumulada", icon: Icons.cloud, isCritical: alertLevel == 2),
                  _SensorCard(title: "Vibración", value: vibrationIntensity.toString(), unit: "Intensidad", icon: Icons.vibration, isCritical: vibrationIntensity > 5),
                  const _SensorCard(title: "Humedad", value: "65%", unit: "Suelo", icon: Icons.grass, isCritical: false),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  final String title, value, unit;
  final IconData icon;
  final bool isCritical;
  const _SensorCard({required this.title, required this.value, required this.unit, required this.icon, required this.isCritical});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: isCritical ? Colors.red[100] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: isCritical ? Colors.red : Colors.blueGrey),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text("$title ($unit)", style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}