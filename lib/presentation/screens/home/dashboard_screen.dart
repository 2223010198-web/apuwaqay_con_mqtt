import 'dart:async'; // Necesario para StreamSubscription
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../app_routes.dart';

// --- SERVICIOS (Arquitectura Limpia) ---
import '../../../data/services/location_service.dart';
import '../../../data/services/sos_service.dart';
import '../../../data/services/simulation_service.dart';
import '../../../data/services/permission_service.dart';
import '../../../data/services/vibration_service.dart';    // ✅ NUEVO
import '../../../data/services/notification_service.dart'; // ✅ NUEVO

// --- COMPONENTES UI ---
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

  // 1. 🛠️ INSTANCIAS DE SERVICIOS (Inyección de Dependencias Manual)
  final LocationService _locationService = LocationService();
  final SosService _sosService = SosService();
  final SimulationService _simulationService = SimulationService();
  final PermissionService _permissionService = PermissionService();
  final VibrationService _vibrationService = VibrationService();       // ✅
  final NotificationService _notificationService = NotificationService(); // ✅

  // 2. 📡 CONEXIÓN A DATOS
  final DocumentReference _sensorDoc = FirebaseFirestore.instance
      .collection('sensores')
      .doc('monitor_principal');

  StreamSubscription<DocumentSnapshot>? _sensorSubscription; // Controla la escucha

  // 3. 📊 ESTADO DE LA UI
  // Variables de Sensores
  double riverLevel = 1.2;
  double rainLevel = 0.0;
  double vibrationIntensity = 0.0;
  double iaConfidence = 0.0;
  int alertLevel = 0; // Nivel actual (0, 1, 2)

  // Variables de Lógica de Control
  int _previousAlertLevel = 0; // Para detectar cambios de estado
  bool isConnected = false;    // Para mostrar estado en UI

  // Variables de Usuario
  String userName = "Usuario";
  bool sosEnabled = true;
  bool realTime = false;
  bool _missingPermissions = true;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSystem(); // Inicialización limpia
  }

  // Carga inicial secuencial
  Future<void> _initSystem() async {
    await _permissionService.requestAllPermissions();
    await _checkPermissionsStatus();
    await _loadUserPreferences();

    // Inicializamos notificaciones
    await _notificationService.init();

    // 🔥 SUSCRIPCIÓN ACTIVA: Escucha cambios en Firebase
    _sensorSubscription = _sensorDoc.snapshots().listen((snapshot) {
      if (snapshot.exists) {
        _processSensorData(snapshot.data() as Map<String, dynamic>);
      }
    }, onError: (e) {
      debugPrint("❌ Error en Firebase: $e");
      if (mounted) setState(() => isConnected = false);
    });
  }

  // ... (Funciones auxiliares _checkPermissionsStatus y _loadUserPreferences se mantienen igual)
  Future<void> _checkPermissionsStatus() async {
    bool hasAll = await _permissionService.hasAllPermissions();
    if (mounted) setState(() => _missingPermissions = !hasAll);
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      userName = prefs.getString('userName') ?? "Usuario";
      sosEnabled = prefs.getBool('sos_enabled') ?? true;
      realTime = prefs.getBool('sos_realtime') ?? false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sensorSubscription?.cancel(); // ⚠️ Importante cancelar para evitar fugas de memoria
    super.dispose();
  }
  // ---------------------------------------------------------------------------
  // 🧠 CEREBRO LÓGICO: PROCESAMIENTO DE DATOS EN TIEMPO REAL
  // ---------------------------------------------------------------------------
  void _processSensorData(Map<String, dynamic> data) {
    if (!mounted) return;

    // 1. Extraer datos con seguridad (valores por defecto si son nulos)
    double newRiver = (data['nivel_rio'] ?? 1.2).toDouble();
    double newRain = (data['precipitacion'] ?? 0.0).toDouble();
    double newVibration = (data['vibracion'] ?? 0.0).toDouble();
    double newConfidence = (data['probabilidad_huayco'] ?? 0.0).toDouble();
    int newAlertLevel = (data['nivel_alerta'] ?? 0).toInt();

    // 2. Detectar CAMBIO CRÍTICO de Estado (De Seguro/Precaución -> PELIGRO)
    if (newAlertLevel == 2 && _previousAlertLevel < 2) {
      _triggerEmergencyProtocols(); // 🔥 ¡ACTIVAR PROTOCOLOS!
    } else if (newAlertLevel < 2 && _previousAlertLevel == 2) {
      // Si bajó el nivel, detenemos la vibración
      _vibrationService.stopVibration();
    }

    // 3. Actualizar la UI
    setState(() {
      riverLevel = newRiver;
      rainLevel = newRain;
      vibrationIntensity = newVibration;
      iaConfidence = newConfidence;
      alertLevel = newAlertLevel;
      _previousAlertLevel = newAlertLevel; // Guardar estado actual para la próxima comparación
      isConnected = true;
    });
  }

  // ---------------------------------------------------------------------------
  // 🔥 PROTOCOLOS DE EMERGENCIA AUTOMÁTICOS
  // ---------------------------------------------------------------------------
  Future<void> _triggerEmergencyProtocols() async {
    debugPrint("🚨 ALERTA ROJA - ACTIVANDO PROTOCOLOS");

    // 1. Vibración (Corrección: usa 'startDangerVibration')
    _vibrationService.startDangerVibration();

    // 2. Notificación (Corrección: usa 'showDangerNotification' sin argumentos)
    _notificationService.showDangerNotification();

    // 3. SOS Automático (Si está habilitado)
    if (sosEnabled) {
      final position = await _locationService.getCurrentOrLastPosition();

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
  // ---------------------------------------------------------------------------
  // 🕹️ FUNCIONES DE USUARIO (Simulación, SOS Manual, Cámara)
  // ---------------------------------------------------------------------------

  // --- SIMULACIÓN LOCAL (Sin escribir en Firebase para no afectar a otros) ---
  void _runSimulation() {
    final simulatedData = _simulationService.getNextSimulationState(alertLevel);
    // Inyectamos los datos simulados directamente al procesador como si vinieran de Firebase
    _processSensorData(simulatedData);

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🐛 Simulación: Datos inyectados localmente"))
    );
  }

  // --- DIÁLOGO DE ADVERTENCIA DE PERMISOS ---
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

  // --- SOS MANUAL (Botón Rojo) ---
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
                Navigator.pushNamed(context, AppRoutes.editSos).then((_) => _loadUserPreferences());
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

  // --- CÁMARA ---
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
            Image.file(imageFile, height: 200, fit: BoxFit.cover),
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
  // ---------------------------------------------------------------------------
  // 🎨 UI HELPERS (Funciones Visuales)
  // ---------------------------------------------------------------------------

  Color getStatusColor(int level) {
    if (level == 0) return Colors.green;
    if (level == 1) return Colors.orange;
    return const Color(0xFFCF0A2C); // Rojo Intenso (Alerta)
  }

  String getStatusText(int level) {
    if (level == 0) return "ZONA SEGURA";
    if (level == 1) return "PRECAUCIÓN";
    return "¡PELIGRO DE HUAYCO!";
  }

  // ---------------------------------------------------------------------------
  // 📱 CONSTRUCCIÓN DE PANTALLA
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Calculamos el ETA (Tiempo estimado) basado en el nivel de alerta
    String etaDisplay = alertLevel == 2
        ? "IMPACTO INMINENTE"
        : (alertLevel == 1 ? "Posible en 45 min" : "");

    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const SideMenu(),

      body: CustomScrollView(
        slivers: [
          // --- APP BAR DINÁMICA (Cambia de color con la alerta) ---
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: getStatusColor(alertLevel),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                  icon: const Icon(Icons.help_outline),
                  tooltip: "Guía de Seguridad",
                  onPressed: () => showDialog(context: context, builder: (_) => const SafetyGuideDialog())
              ),
              // Botón "Simular" (Solo para pruebas)
              IconButton(
                icon: const Icon(Icons.bug_report),
                tooltip: "Simular Evento",
                onPressed: _runSimulation,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(getStatusText(alertLevel),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, shadows: [Shadow(blurRadius: 2, color: Colors.black45, offset: Offset(1, 1))])),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [getStatusColor(alertLevel), getStatusColor(alertLevel).withOpacity(0.8)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Icono animado (podrías agregar animación aquí luego)
                    Icon(alertLevel == 2 ? Icons.campaign : Icons.verified_user,
                        size: 60, color: Colors.white),

                    if (alertLevel > 0) ...[
                      const SizedBox(height: 8),
                      Text(etaDisplay,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      if (iaConfidence > 0)
                        Text("IA Confianza: ${(iaConfidence*100).toStringAsFixed(0)}%",
                            style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    ]
                  ],
                ),
              ),
            ),
          ),

          // --- ACCESO RÁPIDO A MAPA ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () { if (widget.onMapTap != null) widget.onMapTap!(); },
                icon: const Icon(Icons.people_alt),
                label: const Text("Ver Ubicaciones Compartidas"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue[800],
                  elevation: 2,
                ),
              ),
            ),
          ),

          // --- GRILLA DE SENSORES EN TIEMPO REAL ---
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              children: [
                SensorCard(
                    title: "Nivel Río",
                    value: "${riverLevel.toStringAsFixed(1)} m",
                    unit: "Metros",
                    icon: Icons.waves,
                    isCritical: riverLevel > 3.0
                ),
                SensorCard(
                    title: "Lluvia",
                    value: "${rainLevel.toStringAsFixed(0)} mm",
                    unit: "Acumulada",
                    icon: Icons.cloud,
                    isCritical: rainLevel > 100
                ),
                SensorCard(
                    title: "Vibración",
                    value: vibrationIntensity.toStringAsFixed(1),
                    unit: "Hz",
                    icon: Icons.vibration,
                    isCritical: vibrationIntensity > 5
                ),
                // Tarjeta de Estado del Sistema
                SensorCard(
                    title: "Sistema",
                    value: isConnected ? (_locationService.isTracking ? "RASTREO ON" : "ONLINE") : "OFFLINE",
                    unit: "Estado",
                    icon: isConnected ? Icons.cloud_done : Icons.cloud_off,
                    isCritical: !isConnected
                ),
              ],
            ),
          ),
        ],
      ),

      // --- BOTONES FLOTANTES DE ACCIÓN ---
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_missingPermissions && sosEnabled)
            FloatingActionButton.small(
              heroTag: "warn",
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(Icons.warning_amber, color: Colors.amber, size: 40),
              onPressed: () => _permissionService.requestAllPermissions(),
            ),
          const SizedBox(width: 10),
          FloatingActionButton(
            heroTag: "cam",
            backgroundColor: Colors.white,
            child: const Icon(Icons.camera_alt, color: Colors.black),
            onPressed: () async {
              // Lógica simple de cámara
              await Permission.camera.request();
              final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
              if (photo != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Foto guardada")));
              }
            },
          ),
          const SizedBox(width: 15),
          EmergencyButton(
            alertLevel: alertLevel,
            sosEnabled: sosEnabled,
            onConfigure: () => Navigator.pushNamed(context, AppRoutes.editSos).then((_) => _loadUserPreferences()),
            onSendManualSos: () async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enviando alerta manual...")));
              final pos = await _locationService.getCurrentOrLastPosition();
              await _sosService.sendSOSAlert(position: pos, userName: userName, isAuto: false, isTracking: false);
            },
          ),
        ],
      ),
    );
  }
}