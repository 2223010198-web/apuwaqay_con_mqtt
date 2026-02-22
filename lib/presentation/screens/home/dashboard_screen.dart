import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart'; // Importación para permisos
import '../../../data/services/global_alert_service.dart';
import '../../../app_routes.dart';
// ------------- SOLO PARA DEMO
import '../../../data/services/demo_mode_service.dart';
//-------------- SOLO PARA DEMO

// --- SERVICIOS CON CLEAN ARCHITECTURE ---
import '../../../data/services/mqtt_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/sos_service.dart';
import '../../../data/services/simulation_service.dart';
import '../../../data/services/permission_service.dart';
import '../../widgets/emergency_button.dart';
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
  final SosService _sosService = SosService();
  final SimulationService _simulationService = SimulationService();
  final PermissionService _permissionService = PermissionService();
  // ------------- SOLO PARA DEMO
  final DemoModeService _demoModeService = DemoModeService();
  // ------------- SOLO PARA DEMO

  // 2. Variables de Estado UI
  int alertLevel = 0;
  String userName = "Usuario";
  bool sosEnabled = true;
  bool realTime = false;
  bool _missingPermissions = true; // Controla el botón de advertencia amarillo
  // ------------- SOLO PARA DEMO
  bool _isDemoModeActive = false;
  // ------------- SOLO PARA DEMO

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
    // Pide permisos al iniciar y evalúa si falta alguno
    await _permissionService.requestAllPermissions();
    await _checkPermissionsStatus();
    _loadUserData();

    // ------------- SOLO PARA DEMO
    // --- ESCUCHA DEL MODO DEMO (FIREBASE) ---
    _demoModeService.getDemoState().listen((demoData) {
      if (!mounted || demoData == null) return;

      setState(() {
        _isDemoModeActive = demoData['activado'] ?? false;

        if (_isDemoModeActive) {
          alertLevel = (demoData['nivel_alerta'] ?? 0 as num).toInt();
          riverLevel = (demoData['rio'] ?? 1.2 as num).toDouble();
          rainLevel = (demoData['lluvia'] ?? 0.0 as num).toDouble();
          vibrationIntensity = (demoData['vibracion'] ?? 0.0 as num).toDouble();
          iaConfidence = (demoData['probabilidad'] ?? 0.0 as num).toDouble();

          etaHuayco = alertLevel == 2 ? "IMPACTO INMINENTE" : (alertLevel == 1 ? "Posible en 45 min" : "");
        }
      });
    });
    // ------------- SOLO PARA DEMO


    _mqttService.dataStream.listen((data) {
      if (!mounted) return;

      // ------------- SOLO PARA DEMO
      if (_isDemoModeActive) return;
      // ------------- SOLO PARA DEMO

      setState(() {
        riverLevel = (data['rio'] ?? 1.2 as num).toDouble();
        rainLevel = (data['lluvia'] ?? 0.0 as num).toDouble();
        vibrationIntensity = (data['vibracion'] ?? 0.0 as num).toDouble();
        iaConfidence = (data['probabilidad'] ?? 0.0 as num).toDouble();
        alertLevel = (data['nivel_alerta'] ?? 0 as num).toInt();

        etaHuayco = alertLevel == 2 ? "IMPACTO INMINENTE" : (alertLevel == 1 ? "Posible en 45 min" : "");
      });
    });



    GlobalAlertService().eventStream.listen((mensaje) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensaje),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5), // Dura un poco más en pantalla
            )
        );
      }
    });
  }

  Future<void> _checkPermissionsStatus() async {
    bool hasAll = await _permissionService.hasAllPermissions();
    if (mounted) setState(() => _missingPermissions = !hasAll);
  }

  void _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userName = prefs.getString('userName') ?? "Usuario";
      sosEnabled = prefs.getBool('sos_enabled') ?? true;
      realTime = prefs.getBool('sos_realtime') ?? false;
    });
    if (realTime) {
      _locationService.startTracking(onPositionUpdate: (pos) { if (mounted) setState(() {}); });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsStatus(); // Vuelve a revisar permisos al volver a la app
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // --- BOTÓN SIMULADOR (Escalable, usa el servicio) ---
  void _runSimulation() {
    final simulatedData = _simulationService.getNextSimulationState(alertLevel);
    _mqttService.simulateData(simulatedData);
  }

  // --- DIÁLOGO DE ADVERTENCIA DE PERMISOS ---
  void _showPermissionWarningDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [Icon(Icons.warning_amber, color: Colors.orange), SizedBox(width: 8), Text("Permisos Faltantes")],
          ),
          content: const Text("La app necesita permisos (Ubicación, SMS, Cámara) para protegerte correctamente y enviar tu ubicación en una emergencia."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                  _permissionService.requestAllPermissions().then((_) => _checkPermissionsStatus());
                },
                child: const Text("SOLUCIONAR")
            ),
          ],
        )
    );
  }

  // --- SOS MANUAL Y DIÁLOGOS ---
  void _handleSosPress() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.sos, color: Colors.red, size: 32), SizedBox(width: 10), Text("Botón de Emergencia")]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enviaremos tu ubicación GPS por SMS a INDECI y a tus contactos, incluso sin internet.", textAlign: TextAlign.justify),
            const SizedBox(height: 15),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)), child: const Text("💡 Recomendación vital:\nActiva el 'Envío Automático' en la configuración. Pediremos ayuda por ti automáticamente si hay huayco.", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.justify)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton.icon(onPressed: () {Navigator.pop(context); Navigator.pushNamed(context, AppRoutes.editSos).then((_) => _loadUserData());}, icon: const Icon(Icons.settings), label: const Text("Configurar")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () {Navigator.pop(context); _sendManualSOS();}, child: const Text("ENVIAR AHORA", style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Future<void> _sendManualSOS() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Obteniendo GPS preciso y enviando alerta...")));
    final position = await _locationService.getCurrentOrLastPosition();
    int successCount = await _sosService.sendSOSAlert(position: position, userName: userName, isAuto: false, isTracking: _locationService.isTracking);
    if (mounted && successCount > 0) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Alerta SOS enviada a $successCount contactos."), backgroundColor: Colors.green));
  }

  // --- FLUJO DE LA CÁMARA CON PREVISUALIZACIÓN ---
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
      // 2. Abrimos la cámara y esperamos a que tome la foto
      final XFile? photo = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 50 // Comprimimos la imagen
      );

      // 3. Si tomó la foto y no canceló, mostramos el diálogo con la imagen
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
              child: Image.file(
                imageFile,
                height: 250,
                // SOLUCIÓN: En lugar de double.infinity, usamos un ancho máximo finito (el ancho de la pantalla)
                width: MediaQuery.of(context).size.width,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            icon: const Icon(Icons.send),
            label: const Text("ENVIAR REPORTE"),
            onPressed: () {
              Navigator.pop(context); // Cierra el diálogo

              // Aquí en el futuro agregaremos la lógica de:
              // 1. Extraer metadatos
              // 2. Procesamiento de IA para verificar veracidad
              // 3. Envío al servidor

              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ Reporte fotográfico enviado con éxito"), backgroundColor: Colors.green)
              );
            },
          ),
        ],
      ),
    );
  }

  // --- UI HELPERS ---
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
          // --- BOTÓN DE SIMULACIÓN ---
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
          if (_missingPermissions && sosEnabled) ...[
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FloatingActionButton.small(
                heroTag: "btn_warning",
                elevation: 0,
                backgroundColor: Colors.transparent,
                onPressed: _showPermissionWarningDialog,
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

          // --- NUESTRO NUEVO BOTÓN INTELIGENTE ---
          EmergencyButton(
            alertLevel: alertLevel,
            sosEnabled: sosEnabled,
            onConfigure: () {
              Navigator.pushNamed(context, AppRoutes.editSos).then((_) => _loadUserData());
            },
            onSendManualSos: () async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Obteniendo GPS preciso y enviando alerta...")));
              final position = await _locationService.getCurrentOrLastPosition();
              int successCount = await _sosService.sendSOSAlert(
                  position: position,
                  userName: userName,
                  isAuto: false,
                  isTracking: _locationService.isTracking
              );
              if (mounted && successCount > 0) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Alerta SOS enviada a $successCount contactos."), backgroundColor: Colors.green));
              }
            },
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