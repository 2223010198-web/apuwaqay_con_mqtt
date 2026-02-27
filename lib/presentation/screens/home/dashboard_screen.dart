// lib/presentation/screens/home/dashboard_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../app_routes.dart';

// --- SERVICIOS CON CLEAN ARCHITECTURE ---
import '../../../data/services/location_service.dart';
import '../../../data/services/sos_service.dart';
import '../../../data/services/simulation_service.dart';
import '../../../data/services/permission_service.dart';
import '../../../data/services/vibration_service.dart';
import '../../../data/services/notification_service.dart';

// --- COMPONENTES ---
import '../../widgets/emergency_button.dart';
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
  final LocationService _locationService = LocationService();
  final SosService _sosService = SosService();
  final SimulationService _simulationService = SimulationService();
  final PermissionService _permissionService = PermissionService();
  final VibrationService _vibrationService = VibrationService();
  final NotificationService _notificationService = NotificationService();

  final DocumentReference _sensorDoc = FirebaseFirestore.instance
      .collection('sensores')
      .doc('monitor_principal');

  StreamSubscription<DocumentSnapshot>? _sensorSubscription;

  int alertLevel = 0;
  int _previousAlertLevel = 0;
  bool isConnected = false;

  String userName = "Usuario";
  bool sosEnabled = true;
  bool realTime = false;
  bool _missingPermissions = true;

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
    await _permissionService.requestAllPermissions();
    await _checkPermissionsStatus();
    _loadUserData();

    _sensorSubscription = _sensorDoc.snapshots().listen((snapshot) {
      if (snapshot.exists && mounted) {
        _processSensorData(snapshot.data() as Map<String, dynamic>);
      }
    }, onError: (e) {
      debugPrint("❌ Error en Firebase: $e");
      if (mounted) setState(() => isConnected = false);
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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sensorSubscription?.cancel();
    super.dispose();
  }

  void _processSensorData(Map<String, dynamic> data) {
    if (!mounted) return;

    double newRiver = (data['nivel_rio'] ?? 1.2).toDouble();
    double newRain = (data['precipitacion'] ?? 0.0).toDouble();
    double newVibration = (data['vibracion'] ?? 0.0).toDouble();
    double newConfidence = (data['probabilidad_huayco'] ?? 0.0).toDouble();
    int newAlertLevel = (data['nivel_alerta'] ?? 0).toInt();

    if (newAlertLevel != _previousAlertLevel) {
      if (newAlertLevel == 0) {
        _vibrationService.stopVibration();
        _locationService.stopTracking();
      } else if (newAlertLevel == 1) {
        _locationService.stopTracking();
        _vibrationService.startPrecautionVibration();
        _notificationService.showPrecautionNotification();
      } else if (newAlertLevel == 2) {
        _triggerEmergencyProtocols();
      }
    }

    setState(() {
      riverLevel = newRiver;
      rainLevel = newRain;
      vibrationIntensity = newVibration;
      iaConfidence = newConfidence;
      alertLevel = newAlertLevel;
      _previousAlertLevel = newAlertLevel;
      isConnected = true;
    });
  }

  Future<void> _triggerEmergencyProtocols() async {
    debugPrint("🚨 ALERTA ROJA - ACTIVANDO PROTOCOLOS");

    _vibrationService.startDangerVibration();
    _notificationService.showDangerNotification();

    if (realTime && !_locationService.isTracking) {
      _locationService.startTracking(onPositionUpdate: (pos) {
        if (mounted) setState(() {});
      });
    }

    if (sosEnabled) {
      final prefs = await SharedPreferences.getInstance();
      bool autoSend = prefs.getBool('sos_auto_send') ?? false;

      if (autoSend) {
        final position = await _locationService.getCurrentOrLastPosition();
        if (position != null) {
          _sosService.sendSOSAlert(
              position: position,
              userName: userName,
              isAuto: true,
              isTracking: _locationService.isTracking
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("🆘 Alerta SOS enviada automáticamente."),
                  backgroundColor: Colors.redAccent,
                  duration: Duration(seconds: 5),
                )
            );
          }
        }
      }
    }
  }

  void _runSimulation() {
    final simulatedData = _simulationService.getNextSimulationState(alertLevel);
    _processSensorData(simulatedData);

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🐛 Simulación: Datos inyectados localmente"),
        )
    );
  }

  void _showPermissionWarningDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [Icon(Icons.warning_amber, color: Colors.orange), SizedBox(width: 8), Text("Permisos Faltantes")],
          ),
          content: const Text("La app necesita permisos (Ubicación, SMS, Cámara) para protegerte correctamente."),
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

  void _handleSosPress() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.sos, color: Colors.red, size: 32), SizedBox(width: 10), Text("Botón de Emergencia")]),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Se enviará tu ubicación actual a tus contactos de emergencia y a las autoridades locales.", textAlign: TextAlign.justify),
            SizedBox(height: 15),
            Text("Úsalo solo en caso de emergencia real.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.editSos).then((_) => _loadUserData());
              },
              icon: const Icon(Icons.settings),
              label: const Text("Configurar")
          ),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                _sendManualSOS();
              },
              child: const Text("ENVIAR AHORA")
          ),
        ],
      ),
    );
  }

  Future<void> _sendManualSOS() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Obteniendo GPS preciso y enviando alerta...")));
    final position = await _locationService.getCurrentOrLastPosition();
    int successCount = await _sosService.sendSOSAlert(
        position: position,
        userName: userName,
        isAuto: false,
        isTracking: _locationService.isTracking
    );

    if (mounted && successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Alerta SOS enviada a $successCount contactos."), backgroundColor: Colors.green)
      );
    }
  }

  Future<void> _takePhoto() async {
    bool hasCam = await Permission.camera.isGranted;
    if (!hasCam) {
      await Permission.camera.request();
      if (!await Permission.camera.isGranted) return;
    }

    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
      if (photo != null && mounted) {
        _showPhotoConfirmationDialog(File(photo.path));
      }
    } catch (e) {
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
            const Text("¿Enviar esta evidencia al centro de monitoreo?"),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(imageFile, height: 200, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Reporte enviado"), backgroundColor: Colors.green));
              },
              child: const Text("ENVIAR")
          ),
        ],
      ),
    );
  }

  Color getStatusColor(int level) {
    if (level == 0) return const Color(0xFF2E7D32);
    if (level == 1) return const Color(0xFFEF6C00);
    return const Color(0xFFD32F2F);
  }

  String getStatusText(int level) {
    if (level == 0) return "ZONA SEGURA";
    if (level == 1) return "PRECAUCIÓN";
    return "¡PELIGRO INMINENTE!";
  }

  @override
  Widget build(BuildContext context) {
    String etaHuayco = alertLevel == 2
        ? "IMPACTO INMINENTE"
        : (alertLevel == 1 ? "Posible en 45 min" : "");

    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const SideMenu(),
      appBar: AppBar(
        title: const Text("Monitor Apu Waqay"),
        backgroundColor: getStatusColor(alertLevel),
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
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
                color: getStatusColor(alertLevel),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40))
            ),
            child: Column(children: [
              Icon(alertLevel == 2 ? Icons.campaign : Icons.verified_user, size: 80, color: Colors.white),
              const SizedBox(height: 10),
              Text(getStatusText(alertLevel), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              if (alertLevel == 2) Text(etaHuayco, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              if (alertLevel > 0 && iaConfidence > 0) Text("Detectado por IA (${(iaConfidence*100).toStringAsFixed(0)}%)", style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
                onPressed: () { if (widget.onMapTap != null) widget.onMapTap!(); },
                icon: const Icon(Icons.people_alt),
                label: const Text("Ver Ubicaciones Compartidas"),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50))
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 75),
              child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  children: [
                    SensorCard(title: "Nivel Río", value: "${riverLevel.toStringAsFixed(1)} m", unit: "Metros", icon: Icons.waves, isCritical: riverLevel > 3.0),
                    SensorCard(title: "Lluvia", value: "${rainLevel.toStringAsFixed(0)} mm", unit: "Acumulada", icon: Icons.cloud, isCritical: rainLevel > 100),
                    SensorCard(title: "Vibración", value: vibrationIntensity.toStringAsFixed(1), unit: "Hz", icon: Icons.vibration, isCritical: vibrationIntensity > 5),
                    SensorCard(title: "Rastreo", value: _locationService.isTracking ? "ACTIVO" : "INACTIVO", unit: "GPS", icon: _locationService.isTracking ? Icons.radar : Icons.location_disabled, isCritical: false),
                  ]
              ),
            ),
          )
        ],
      ),
    );
  }
}