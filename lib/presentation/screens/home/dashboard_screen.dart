import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../app_routes.dart';

// --- SERVICIOS ---
import '../../../data/services/mqtt_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/vibration_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/sos_service.dart';
import '../../../data/services/simulation_service.dart';
import '../../../data/services/permission_service.dart'; // <--- NUEVO SERVICIO

// --- COMPONENTES ---
import '../../widgets/side_menu.dart';
import '../../widgets/sensor_card.dart';
import '../../widgets/safety_guide_dialog.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onMapTap;
  const DashboardScreen({super.key, this.onMapTap});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  // 1. Instancias de Servicios
  final MqttService _mqttService = MqttService();
  final LocationService _locationService = LocationService();
  final VibrationService _vibrationService = VibrationService();
  final NotificationService _notificationService = NotificationService();
  final SosService _sosService = SosService();
  final SimulationService _simulationService = SimulationService();
  final PermissionService _permissionService = PermissionService(); // <--- INSTANCIA PERMISOS

  // 2. Variables de Estado UI
  int alertLevel = 0;
  String userName = "Usuario";
  bool sosEnabled = true;
  bool autoSend = false;
  bool realTime = false;
  bool _missingPermissions = true; // <--- VARIABLE RECUPERADA PARA EL BOTÓN AMARILLO

  double vibrationIntensity = 0.0;
  double rainLevel = 0.0;
  double riverLevel = 1.2;
  double iaConfidence = 0.0;
  String etaHuayco = "";

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initApp();
  }

  Future<void> _initApp() async {
    await _notificationService.init();

    // RECUPERADO: Petición global de permisos al iniciar
    await _permissionService.requestAllPermissions();
    _checkPermissionsStatus();

    _loadUserData();
    _initMqtt();
  }

  // RECUPERADO: Verifica si falta algún permiso para mostrar/ocultar el botón amarillo
  Future<void> _checkPermissionsStatus() async {
    bool hasAll = await _permissionService.hasAllPermissions();
    if (mounted) {
      setState(() {
        _missingPermissions = !hasAll;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vibrationService.stopVibration();
    _locationService.stopTracking();
    _mqttService.disconnect();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsStatus(); // Vuelve a chequear permisos al volver a la app
      if (realTime) _startRastreo();
    }
  }

  void _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userName = prefs.getString('userName') ?? "Usuario";
      sosEnabled = prefs.getBool('sos_enabled') ?? true;
      autoSend = prefs.getBool('sos_auto_send') ?? false;
      realTime = prefs.getBool('sos_realtime') ?? false;
    });
    if (realTime) _startRastreo();
  }

  void _startRastreo() {
    _locationService.startTracking(onPositionUpdate: (pos) {
      if (mounted) setState(() {});
    });
  }

  void _initMqtt() async {
    await _mqttService.connect();
    _mqttService.dataStream.listen((data) {
      _updateDashboardFromData(data);
    });
  }

  void _runSimulation() {
    final simulatedData = _simulationService.getNextSimulationState(alertLevel);
    _updateDashboardFromData(simulatedData);
  }

  void _updateDashboardFromData(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      riverLevel = (data['rio'] ?? 1.2 as num).toDouble();
      rainLevel = (data['lluvia'] ?? 0.0 as num).toDouble();
      vibrationIntensity = (data['vibracion'] ?? 0.0 as num).toDouble();
      iaConfidence = (data['probabilidad'] ?? 0.0 as num).toDouble();

      int newAlertLevel = (data['nivel_alerta'] ?? 0 as num).toInt();

      if (newAlertLevel != alertLevel) {
        alertLevel = newAlertLevel;
        _handleAlertStateChange(alertLevel);
      }
    });
  }

  void _handleAlertStateChange(int level) {
    _vibrationService.stopVibration();
    etaHuayco = "";

    if (level == 1) {
      etaHuayco = "Posible en 45 min";
      _notificationService.showPrecautionNotification();
      _vibrationService.startPrecautionVibration();

    } else if (level == 2) {
      etaHuayco = "IMPACTO INMINENTE";
      _notificationService.showDangerNotification();
      _vibrationService.startDangerVibration();

      if (autoSend) {
        debugPrint("⚡ ALERTA ROJA: Enviando SOS Automático...");
        _sendSOS(isAuto: true);
      }
    }
  }

  // --- RECUPERADO: DIÁLOGO DE ADVERTENCIA DE PERMISOS ---
  void _showPermissionWarningDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text("Permisos Faltantes"),
            ],
          ),
          content: const Text("La app necesita permisos (Ubicación, SMS, Cámara) para protegerte correctamente y enviar tu ubicación en una emergencia."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                  _permissionService.requestAllPermissions().then((_) => _checkPermissionsStatus());
                  // Opcionalmente: _permissionService.openSettings();
                },
                child: const Text("SOLUCIONAR")
            ),
          ],
        )
    );
  }

  void _handleSosPress() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [Icon(Icons.sos, color: Colors.red, size: 32), SizedBox(width: 10), Text("Botón de Emergencia")],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Al presionar ENVIAR, mandaremos tu ubicación GPS por SMS a las autoridades e INDECI, incluso sin internet.", textAlign: TextAlign.justify),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
              child: const Text("💡 Recomendación vital:\nActiva el 'Envío Automático' en la configuración. Si el sensor de la IA detecta el huayco, pediremos ayuda por ti aunque no puedas tocar tu celular.", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.justify),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton.icon(onPressed: () {Navigator.pop(context); Navigator.pushNamed(context, AppRoutes.editSos).then((_) => _loadUserData());}, icon: const Icon(Icons.settings), label: const Text("Configurar")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () {Navigator.pop(context); _sendSOS(isAuto: false);}, child: const Text("ENVIAR SOS AHORA", style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Future<void> _sendSOS({bool isAuto = false}) async {
    if (mounted && !isAuto) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Obteniendo GPS preciso y enviando alerta...")));
    final position = await _locationService.getCurrentOrLastPosition();
    int successCount = await _sosService.sendSOSAlert(position: position, userName: userName, isAuto: isAuto, isTracking: _locationService.isTracking);
    if (mounted && successCount > 0 && !isAuto) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Alerta SOS enviada a $successCount contactos."), backgroundColor: Colors.green));
  }

  // --- RECUPERADO: FLUJO DE LA CÁMARA CORREGIDO ---
  Future<void> _takePhoto() async {
    // 1. Verificamos que tenga permiso de cámara
    bool hasCam = await Permission.camera.isGranted;
    if (!hasCam) {
      await Permission.camera.request();
      if (!await Permission.camera.isGranted) {
        if(!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permiso de cámara denegado.")));
        return;
      }
    }

    try {
      // 2. Abrimos la cámara y ESPERAMOS a que tome la foto
      final XFile? photo = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 50 // Comprimimos la imagen para que sea ligera
      );

      // 3. Si tomó la foto y no canceló, mostramos el diálogo
      if (photo != null && mounted) {
        _showPhotoConfirmationDialog(File(photo.path));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo acceder a la cámara")));
      debugPrint("Error cámara: $e");
    }
  }

  void _showPhotoConfirmationDialog(File imageFile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Reporte"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("¿Deseas enviar esta foto de evidencia al centro de monitoreo comunal?"),
            const SizedBox(height: 15),
            // VISTA PREVIA CORREGIDA
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              // Limitamos la altura para que no desborde la pantalla
              child: Image.file(imageFile, height: 250, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            icon: const Icon(Icons.send),
            label: const Text("ENVIAR REPORTE"),
            onPressed: () {
              Navigator.pop(context); // Cierra el diálogo
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ Reporte fotográfico enviado con éxito"), backgroundColor: Colors.green)
              );
            },
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const SideMenu(),
      appBar: AppBar(
        title: const Text("Monitor Apu Waqay"),
        backgroundColor: getStatusColor(),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: "Guía de Seguridad",
              onPressed: () => showDialog(context: context, builder: (_) => const SafetyGuideDialog())
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: "Simular Evento",
            onPressed: _runSimulation,
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // --- RECUPERADO: BOTÓN AMARILLO DE PERMISOS ---
          if (_missingPermissions && sosEnabled) ...[
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FloatingActionButton.small(
                heroTag: "btn_warning",
                elevation: 0,
                backgroundColor: Colors.transparent,
                onPressed: _showPermissionWarningDialog, // Llama al diálogo
                child: const Icon(Icons.warning_amber, color: Colors.amber, size: 40),
              ),
            ),
          ],
          FloatingActionButton(
            heroTag: "btn_camara",
            onPressed: _takePhoto,
            backgroundColor: Colors.white,
            tooltip: "Reportar Huayco (Cámara)",
            child: const Icon(Icons.camera_alt, color: Colors.black87),
          ),
          const SizedBox(width: 15),
          if (sosEnabled) FloatingActionButton.extended(
            heroTag: "btn_sos",
            onPressed: _handleSosPress,
            backgroundColor: alertLevel == 0 ? Colors.grey : Colors.red[900],
            icon: const Icon(Icons.sos, color: Colors.white),
            label: const Text("SOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: getStatusColor(), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40))),
            child: Column(children: [
              Icon(alertLevel == 2 ? Icons.campaign : Icons.verified_user, size: 80, color: Colors.white),
              const SizedBox(height: 10),
              Text(getStatusText(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              if (alertLevel == 2) Text(etaHuayco, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              if (alertLevel > 0 && iaConfidence > 0) Text("Detectado por IA (${(iaConfidence*100).toStringAsFixed(0)}%)", style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(onPressed: () { if (widget.onMapTap != null) widget.onMapTap!(); }, icon: const Icon(Icons.people_alt), label: const Text("Ver Ubicaciones Compartidas"), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50))),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 75),
              child: GridView.count(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, children: [
                SensorCard(title: "Nivel Río", value: "${riverLevel.toStringAsFixed(1)} m", unit: "Metros", icon: Icons.waves, isCritical: riverLevel > 3.0),
                SensorCard(title: "Lluvia", value: "${rainLevel.toStringAsFixed(0)} mm", unit: "Acumulada", icon: Icons.cloud, isCritical: rainLevel > 100),
                SensorCard(title: "Vibración", value: vibrationIntensity.toStringAsFixed(1), unit: "Hz", icon: Icons.vibration, isCritical: vibrationIntensity > 5),
                SensorCard(title: "Rastreo", value: _locationService.isTracking ? "ACTIVO" : "INACTIVO", unit: "GPS", icon: _locationService.isTracking ? Icons.radar : Icons.location_disabled, isCritical: false),
              ]),
            ),
          )
        ],
      ),
    );
  }
}