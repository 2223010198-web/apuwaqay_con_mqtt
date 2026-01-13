import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para el canal nativo
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart'; // <--- OBLIGATORIO
import '../../../app_routes.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  int alertLevel = 0;
  String userName = "Usuario";
  bool sosEnabled = true;
  bool autoSend = false;
  bool realTime = false;
  double vibrationIntensity = 0.0;
  String etaHuayco = "";

  // Canal nativo para enviar SMS (El que ya te funciona)
  static const platform = MethodChannel('com.apuwaqay/sms');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();

    // 1. PEDIR PERMISOS AL ABRIR LA PANTALLA
    // Esperamos un poco a que la UI cargue para no bloquear el inicio
    Future.delayed(const Duration(seconds: 1), () {
      _requestAllPermissions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Detectar si el usuario vuelve a la app desde Ajustes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && alertLevel == 1) {
      _checkPermissionsForWarning();
    }
  }

  // --- FUNCIÓN PARA PEDIR TODOS LOS PERMISOS ---
  Future<void> _requestAllPermissions() async {
    // Pedimos Ubicación, SMS y Teléfono (necesarios para el envío)
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.sms,
      Permission.phone,
    ].request();

    // Opcional: Mostrar aviso si algo fue denegado
    if (statuses[Permission.sms]!.isDenied || statuses[Permission.location]!.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Se requieren permisos para el sistema SOS")),
        );
      }
    }
  }

  // --- VALIDACIÓN ALERTA NARANJA ---
  Future<void> _checkPermissionsForWarning() async {
    // Solo si el botón SOS está habilitado y estamos en precaución
    if (sosEnabled && alertLevel == 1) {
      if (await Permission.sms.isDenied || await Permission.location.isDenied) {
        // Mostrar diálogo explicando por qué pedimos permisos de nuevo
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("⚠️ Precaución Activada"),
              content: const Text("El nivel de riesgo ha subido. Para que el SOS funcione, necesitamos acceso a SMS y Ubicación."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _requestAllPermissions(); // Pedir de nuevo
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

  void _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? "Usuario";
      sosEnabled = prefs.getBool('sos_enabled') ?? true;
      autoSend = prefs.getBool('sos_auto_send') ?? false;
      realTime = prefs.getBool('sos_realtime') ?? false;
    });
  }

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

  void _simulateChange() async {
    setState(() {
      alertLevel = (alertLevel + 1) % 3;
      if (alertLevel == 0) {
        vibrationIntensity = 0.1;
        etaHuayco = "";
      } else if (alertLevel == 1) {
        vibrationIntensity = 3.5;
        etaHuayco = "Posible en 45 min";
        // --- AQUÍ ACTIVAMOS LA VERIFICACIÓN DE PERMISOS ---
        _checkPermissionsForWarning();
      } else {
        vibrationIntensity = 7.8;
        etaHuayco = "IMPACTO EN 15 MIN";
      }
    });

    if (alertLevel == 2) {
      bool canVibrate = await Vibrate.canVibrate;
      if (canVibrate) {
        Vibrate.vibrateWithPauses([const Duration(milliseconds: 500), const Duration(milliseconds: 500)]);
      }
      if (autoSend) {
        _sendSOS(isAuto: true);
      }
      _showEmergencyDialog();
    }
  }

  // --- ENVÍO SOS (NATIVO) ---
  Future<void> _sendSOS({bool isAuto = false}) async {
    if (!isAuto && alertLevel == 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sistema Seguro.")));
      return;
    }

    // Doble verificación de permisos antes de enviar
    if (await Permission.sms.isDenied) {
      await Permission.sms.request();
      if (await Permission.sms.isDenied) return; // Si sigue denegado, salimos
    }

    // Obtener GPS
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

    // NÚMEROS DE DESTINO
    List<String> recipients = ["992934043"]; // TU NÚMERO
    if (c1.isNotEmpty) recipients.add(c1);
    if (c2.isNotEmpty) recipients.add(c2);

    String mapsLink = "http://maps.google.com/?q=${position.latitude},${position.longitude}";
    String msg = "¡SOS HUAYCO! Soy $userName. UBICACION: $mapsLink";

    // Enviar por Canal Nativo
    int successCount = 0;
    for (String number in recipients) {
      try {
        await platform.invokeMethod('sendDirectSMS', {
          "phone": number,
          "msg": msg
        });
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
            onPressed: () => Navigator.pop(context),
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
      floatingActionButton: sosEnabled ? FloatingActionButton.extended(
        onPressed: () => _sendSOS(isAuto: false),
        backgroundColor: alertLevel == 0 ? Colors.grey : Colors.red[900],
        icon: const Icon(Icons.sos, color: Colors.white, size: 30),
        label: Text(alertLevel == 0 ? "SOS (Inactivo)" : "SOS", style: const TextStyle(color: Colors.white)),
      ) : null,
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
                  const _SensorCard(title: "Conexión", value: "4G LTE", unit: "Red", icon: Icons.signal_cellular_alt, isCritical: false),
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