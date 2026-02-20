import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app_routes.dart';
// --- SERVICIOS EXTRAÍDOS ---
import '../../../data/services/mqtt_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/sos_service.dart';
import '../../../data/services/mqtt_service.dart';

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
  // 1. INYECCIÓN DE SERVICIOS
  final MqttService _mqttService = MqttService();
  final NotificationService _notificationService = NotificationService();
  final LocationService _locationService = LocationService();
  final SosService _sosService = SosService();
  StreamSubscription? _mqttSubscription;

  // 2. VARIABLES DE ESTADO UI
  int alertLevel = 0;
  String userName = "Usuario";
  bool sosEnabled = true;
  bool autoSend = false;
  bool realTime = false;
  bool _missingPermissions = true;

  double vibrationIntensity = 0.0;
  double rainLevel = 0.0;
  double riverLevel = 1.2;
  String etaHuayco = "";

  Timer? _vibrationTimer;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Inicialización de servicios
    _notificationService.init();
    _loadUserData();
    _checkPermissionsStatus();

    Future.delayed(const Duration(seconds: 1), () {
      _requestAllPermissions();
    });

    _initMqtt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopVibration();
    _locationService.stopTracking();
    _mqttService.client.disconnect();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsStatus();
      if (alertLevel == 1) _checkPermissionsForWarning();
      if (realTime) _startRastreo();
    }
  }

  // --- LÓGICA DE SERVICIOS ---

  void _initMqtt() async {
    // Conectar al broker
    await _mqttService.connect();

    // Empezar a escuchar los datos
    _mqttSubscription = _mqttService.dataStream.listen((data) {
      if (!mounted) return;

      setState(() {
        // 1. Extraer los datos del JSON que envía tu Raspberry
        riverLevel = (data['rio'] ?? 1.2 as num).toDouble();
        rainLevel = (data['lluvia'] ?? 0.0 as num).toDouble();
        vibrationIntensity = (data['vibracion'] ?? 0.0 as num).toDouble();

        // La probabilidad de la IA
        double iaConf = (data['probabilidad'] ?? 0.0 as num).toDouble();

        // 2. Revisar si hay un cambio en el nivel de alerta
        int newAlertLevel = (data['nivel_alerta'] ?? 0 as num).toInt();

        if (newAlertLevel != alertLevel) {
          alertLevel = newAlertLevel;
          _handleAlertStateChange(alertLevel); // Activa sirenas, vibración, etc.
        }
      });
    });
  }

  void _startRastreo() {
    _locationService.startTracking(onPositionUpdate: (pos) {
      if (mounted) setState(() {}); // Solo refresca la UI si es necesario
    });
  }

  void _handleAlertStateChange(int level) {
    _stopVibration(); // Detener vibraciones anteriores
    etaHuayco = "";

    if (level == 1) {
      etaHuayco = "Posible en 45 min";
      _notificationService.showWarningNotification("⚠️ PRECAUCIÓN", "Nivel del río subiendo.");
      _startVibrationPattern(isRedAlert: false);
      if(mounted) _showCautionDialog();
    } else if (level == 2) {
      etaHuayco = "IMPACTO INMINENTE";
      _notificationService.showWarningNotification("🚨 PELIGRO: HUAYCO", "¡Evacúa inmediatamente!");
      _startVibrationPattern(isRedAlert: true);
      if (autoSend) _sendSOS(isAuto: true);
      if(mounted) _showEmergencyDialog();
    }
  }

  Future<void> _sendSOS({bool isAuto = false}) async {
    if (mounted && !isAuto) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enviando alerta prioritaria...")));
    }

    // Usamos el servicio GPS para obtener coordenada
    final position = await _locationService.getCurrentOrLastPosition();

    // Usamos el servicio SOS para enviar SMS
    int successCount = await _sosService.sendSOSAlert(
      position: position,
      userName: userName,
      isAuto: isAuto,
      isTracking: _locationService.isTracking,
    );

    if (mounted && successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Alerta enviada a $successCount contactos."), backgroundColor: Colors.green));
    } else if (mounted && successCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Falla enviando SMS o sin GPS."), backgroundColor: Colors.red));
    }
  }

  // --- LÓGICA DE UI Y CONFIGURACIONES ---

  void _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? "Usuario";
      sosEnabled = prefs.getBool('sos_enabled') ?? true;
      autoSend = prefs.getBool('sos_auto_send') ?? false;
      realTime = prefs.getBool('sos_realtime') ?? false;
    });
    if (realTime) _startRastreo();
  }

  Future<void> _checkPermissionsStatus() async {
    bool loc = await Permission.location.isGranted;
    bool sms = await Permission.sms.isGranted;
    bool cam = await Permission.camera.isGranted;
    if (mounted) setState(() => _missingPermissions = !(loc && sms && cam));
  }

  Future<void> _requestAllPermissions() async {
    await [Permission.location, Permission.sms, Permission.phone, Permission.notification, Permission.camera].request();
    _checkPermissionsStatus();
  }

  // ... (MANTENEMOS TUS FUNCIONES DE CÁMARA Y DIÁLOGOS INTACTAS)
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
      if (photo != null && mounted) _showPhotoConfirmationDialog(File(photo.path));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo acceder a la cámara")));
    }
  }

  void _showPhotoConfirmationDialog(File imageFile) {
    // ... Tu código original del diálogo de foto (omitido por brevedad, pégalo aquí)
  }

  void _startVibrationPattern({required bool isRedAlert}) {
    _stopVibration();
    int counter = 0;
    int maxDuration = isRedAlert ? 15 : 5;
    if (isRedAlert) {
      _triggerVibrate();
      _vibrationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        counter += 3;
        if (counter >= maxDuration) _stopVibration(); else _triggerVibrate();
      });
    } else {
      _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
        counter++;
        if (counter >= (maxDuration * 2)) _stopVibration(); else Vibrate.feedback(FeedbackType.warning);
      });
    }
  }

  void _triggerVibrate() async {
    if (await Vibrate.canVibrate) Vibrate.vibrateWithPauses([const Duration(milliseconds: 100), const Duration(milliseconds: 1000)]);
  }

  void _stopVibration() => _vibrationTimer?.cancel();

  // DIÁLOGOS DE ALERTA
  void _showSafeModeDialog() { /* ... Tu código original ... */ }
  Future<void> _showWarningConfirmationDialog() async { /* ... Tu código original ... */ }
  void _showCautionDialog() { /* ... Tu código original ... */ }
  void _showEmergencyDialog() { /* ... Tu código original ... */ }
  void _checkPermissionsForWarning() { /* ... Tu código original ... */ }
  void _showPermissionWarningDialog() { /* ... Tu código original ... */ }

  void _simulateChange() {
    setState(() {
      alertLevel = (alertLevel + 1) % 3;
      _handleAlertStateChange(alertLevel);
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
          IconButton(icon: const Icon(Icons.help_outline), onPressed: () => showDialog(context: context, builder: (_) => const SafetyGuideDialog())),
          IconButton(icon: const Icon(Icons.bug_report), onPressed: _simulateChange),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_missingPermissions && sosEnabled) Padding(padding: const EdgeInsets.only(right: 10), child: FloatingActionButton.small(heroTag: "btn_warning", elevation: 0, backgroundColor: Colors.transparent, onPressed: _showPermissionWarningDialog, child: const Icon(Icons.warning_amber, color: Colors.amber, size: 40))),
          FloatingActionButton(heroTag: "btn_camara", onPressed: _takePhoto, backgroundColor: Colors.white, child: const Icon(Icons.camera_alt, color: Colors.black87)),
          const SizedBox(width: 15),
          if (sosEnabled) FloatingActionButton.extended(
            heroTag: "btn_sos",
            onPressed: () => alertLevel == 0 ? _showSafeModeDialog() : (alertLevel == 1 ? _showWarningConfirmationDialog() : _sendSOS(isAuto: false)),
            backgroundColor: alertLevel == 0 ? Colors.grey : Colors.red[900],
            icon: const Icon(Icons.sos, color: Colors.white),
            label: const Text("SOS", style: TextStyle(color: Colors.white)),
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
              if (alertLevel == 2) Text("LLEGADA ESTIMADA: $etaHuayco", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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