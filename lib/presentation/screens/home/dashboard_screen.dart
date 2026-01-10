import 'package:flutter/material.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:geolocator/geolocator.dart'; // Para obtener GPS
import 'package:url_launcher/url_launcher.dart'; // Para abrir SMS

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int alertLevel = 0;

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

  // --- LÓGICA SOS (NUEVO) ---
  Future<void> _sendSOS() async {
    // 1. Verificar permisos de GPS
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // 2. Mostrar carga mientras obtenemos satélites
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Obteniendo coordenadas GPS...")),
    );

    // 3. Obtener posición actual
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
    );

    // 4. Crear mensaje con Link de Google Maps
    String mapsLink = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
    String message = "¡AYUDA! Estoy en zona de riesgo de huayco. Mi ubicación es: $mapsLink";

    // 5. Preparar el SMS (Esquema universal)
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: '999999999', // Aquí iría el número de emergencia configurado
      queryParameters: <String, String>{
        'body': message,
      },
    );

  // 6. Lanzar la app de mensajes (Código mejorado)
      try {
        // Intentamos abrirlo forzando "Aplicación Externa"
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        // Si falla, intentamos el método simple
        final Uri smsUriSimple = Uri.parse("sms:999999999?body=$message");
        if (await canLaunchUrl(smsUriSimple)) {
          await launchUrl(smsUriSimple, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error al abrir SMS: $e")),
            );
          }
        }
      }
  }

  void _simulateChange() async {
    setState(() {
      alertLevel = (alertLevel + 1) % 3;
    });

    if (alertLevel == 2) {
      bool canVibrate = await Vibrate.canVibrate;
      if (canVibrate) {
        Vibrate.vibrateWithPauses([
          const Duration(milliseconds: 500),
          const Duration(milliseconds: 500),
          const Duration(milliseconds: 500),
        ]);
      }
      _showEmergencyDialog();
    }
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red[50],
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 10),
            Text("ALERTA CRÍTICA", style: TextStyle(color: Colors.red)),
          ],
        ),
        content: const Text(
          "Se ha detectado un aumento crítico en el caudal del río. \n\nEVACUAR A ZONAS ALTAS.",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
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
      appBar: AppBar(
        title: const Text("Apu Waqay Monitor", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: getStatusColor(),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.white),
            onPressed: _simulateChange,
            tooltip: "Simular Cambio de Estado",
          )
        ],
      ),

      // --- BOTÓN FLOTANTE SOS (NUEVO) ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sendSOS,
        backgroundColor: Colors.red[900],
        icon: const Icon(Icons.sos, color: Colors.white, size: 30),
        label: const Text("SOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),

      body: Column(
        children: [
          // Tarjeta Gigante
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: getStatusColor(),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
              boxShadow: [
                BoxShadow(color: getStatusColor().withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))
              ],
            ),
            child: Column(
              children: [
                Icon(
                    alertLevel == 2 ? Icons.campaign : Icons.verified_user,
                    size: 80,
                    color: Colors.white
                ),
                const SizedBox(height: 10),
                Text(
                  getStatusText(),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  "Última actualización: hace 1 min",
                  style: TextStyle(color: Colors.white.withOpacity(0.8)),
                )
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Grilla de Sensores
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  _SensorCard(
                    title: "Nivel Río",
                    value: alertLevel == 2 ? "4.5 m" : "1.2 m",
                    unit: "Metros",
                    icon: Icons.waves,
                    isCritical: alertLevel == 2,
                  ),
                  _SensorCard(
                    title: "Lluvia",
                    value: alertLevel == 2 ? "120 mm" : "0 mm",
                    unit: "Acumulada",
                    icon: Icons.cloud,
                    isCritical: alertLevel == 2,
                  ),
                  const _SensorCard(title: "Humedad", value: "65%", unit: "Suelo", icon: Icons.grass, isCritical: false),
                  const _SensorCard(title: "Batería", value: "98%", unit: "Sistema", icon: Icons.battery_charging_full, isCritical: false),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

// Widget auxiliar para las tarjetas
class _SensorCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final bool isCritical;

  const _SensorCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.isCritical,
  });

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
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text("$title ($unit)", style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}