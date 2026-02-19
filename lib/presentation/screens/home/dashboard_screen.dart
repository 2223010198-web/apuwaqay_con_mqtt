import 'dart:async'; // Para Streams y Timers
import 'dart:io'; // Para manejar el archivo de la foto
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';

import 'package:geolocator/geolocator.dart'; // Tecnología base compatible con Huawei/Android
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart'; // Para la cámara
import '../../../app_routes.dart';
import '../../../data/services/mqtt_service.dart';


// --- IMPORTS DE COMPONENTES REUTILIZABLES ---
import '../../widgets/side_menu.dart';
import '../../widgets/sensor_card.dart';
import '../../widgets/safety_guide_dialog.dart';

class DashboardScreen extends StatefulWidget {
//  const DashboardScreen({super.key});

  final VoidCallback? onMapTap;

  // --- ACTUALIZAMOS EL CONSTRUCTOR ---
  const DashboardScreen({super.key, this.onMapTap});



  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final MqttService _mqttService = MqttService();
  // --- VARIABLES DE ESTADO ---
  int alertLevel = 0;
  String userName = "Usuario";
  bool sosEnabled = true;
  bool autoSend = false;
  bool realTime = false; // Controla el rastreo continuo
  double vibrationIntensity = 0.0;
  String etaHuayco = "";

  bool _missingPermissions = true;

  // --- VARIABLES DE UBICACIÓN ---
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _lastKnownPosition;
  bool _isTracking = false;

  static const platform = MethodChannel('com.apuwaqay/sms');
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  Timer? _vibrationTimer;

  // --- VARIABLE PARA CÁMARA ---
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    _initNotifications();
    _checkPermissionsStatus();

    Future.delayed(const Duration(seconds: 1), () {
      _requestAllPermissions();
    });
    _initMqtt();
  }

  void _initMqtt() async {
    await _mqttService.connect();

    // Escuchar el stream de datos
    _mqttService.dataStream.listen((data) {
      if (!mounted) return;

      setState(() {
        // Actualizar variables con datos reales de la Raspberry
        alertLevel = data['nivel_alerta']; // 0 o 2
        vibrationIntensity = (data['vibracion'] as num).toDouble();

        // Actualizar UI según nivel
        if (alertLevel == 2) {
          etaHuayco = "INMINENTE";
          // Opcional: disparar vibración del celular aquí también
        } else {
          etaHuayco = "";
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopVibration();
    _stopLocationStream();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsStatus();
      if (alertLevel == 1) _checkPermissionsForWarning();
      if (realTime && !_isTracking) _startLocationStream();
    }
  }

  // --- 1. MOTOR DE UBICACIÓN ---
  void _startLocationStream() async {
    if (_isTracking) return;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    try {
      _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen((Position position) {
        setState(() {
          _lastKnownPosition = position;
          _isTracking = true;
        });
        debugPrint("📍 Rastreo Activo: ${position.latitude}, ${position.longitude}");
      });
    } catch (e) {
      debugPrint("Error iniciando rastreo: $e");
    }
  }

  void _stopLocationStream() {
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
      setState(() => _isTracking = false);
    }
  }

  // --- 2. NOTIFICACIONES ---
  void _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'apu_waqay_alerts', 'Alertas de Huayco',
        importance: Importance.max, priority: Priority.high, ticker: 'ticker');
    await _notificationsPlugin.show(0, title, body, NotificationDetails(android: androidDetails));
  }

  // --- 3. PERMISOS ---
  Future<void> _checkPermissionsStatus() async {
    bool loc = await Permission.location.isGranted;
    bool sms = await Permission.sms.isGranted;
    bool phone = await Permission.phone.isGranted;
    bool camera = await Permission.camera.isGranted;

    if (mounted) setState(() => _missingPermissions = !(loc && sms && phone && camera));
  }

  Future<void> _requestAllPermissions() async {
    await [
      Permission.location,
      Permission.sms,
      Permission.phone,
      Permission.notification,
      Permission.camera
    ].request();
    _checkPermissionsStatus();
  }

  Future<void> _checkPermissionsForWarning() async {
    if (sosEnabled && alertLevel == 1 && _missingPermissions) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("⚠️ Precaución Activada"),
            content: const Text("Necesitamos permisos (SMS, Ubicación, Cámara) para protegerte."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
              ElevatedButton(onPressed: () {Navigator.pop(context); _requestAllPermissions();}, child: const Text("Dar Permisos")),
            ],
          ),
        );
      }
    }
  }

  // --- 4. LÓGICA SOS ---
  void _handleSosPress() {
    if (alertLevel == 0) {
      _showSafeModeDialog();
    } else if (alertLevel == 1) {
      _showWarningConfirmationDialog();
    } else {
      _sendSOS(isAuto: false);
    }
  }

  void _showSafeModeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.info_outline, color: Colors.blue), SizedBox(width: 10), Text("Información SOS")]),
        content: const Text(
          "El botón SOS envía tu ubicación a INDECI y tus contactos.\n\nPuedes personalizar los números en Configuración.",
          textAlign: TextAlign.justify,
        ),
        actions: [
          TextButton(
            onPressed: () {Navigator.pop(context); Navigator.pushNamed(context, AppRoutes.editSos).then((_) => _loadUserData());},
            child: const Text("CONFIGURAR"),
          ),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("ENTENDIDO")),
        ],
      ),
    );
  }

  Future<void> _showWarningConfirmationDialog() async {
    final prefs = await SharedPreferences.getInstance();
    String c1 = prefs.getString('sos_contact_1') ?? "";
    String c2 = prefs.getString('sos_contact_2') ?? "";
    String contacts = "• INDECI (115)\n" + (c1.isNotEmpty ? "• $c1\n" : "") + (c2.isNotEmpty ? "• $c2\n" : "");

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.orange[50],
        title: const Text("¿Enviar Alerta de Precaución?"),
        content: Text("Se enviará tu ubicación a:\n\n$contacts"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
            onPressed: () {Navigator.pop(context); _sendSOS(isAuto: false);},
            child: const Text("ENVIAR AHORA"),
          ),
        ],
      ),
    );
  }

  // --- 5. ENVÍO SOS ---
  Future<void> _sendSOS({bool isAuto = false}) async {
    if (await Permission.sms.isDenied) await Permission.sms.request();
    if (await Permission.location.isDenied) await Permission.location.request();

    if (mounted && !isAuto) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enviando alerta prioritaria...")));
    }

    Position position;
    try {
      if (_lastKnownPosition != null && DateTime.now().difference(_lastKnownPosition!.timestamp).inMinutes < 2) {
        position = _lastKnownPosition!;
        debugPrint("🚀 Usando ubicación en caché (Tiempo Real)");
      } else {
        position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      }
    } catch (e) {
      debugPrint("Error GPS: $e");
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    String c1 = prefs.getString('sos_contact_1') ?? "";
    String c2 = prefs.getString('sos_contact_2') ?? "";
    List<String> recipients = ["968892408"];
    if (c1.isNotEmpty) recipients.add(c1);
    if (c2.isNotEmpty) recipients.add(c2);

    String mapsLink = "https://maps.google.com/?q=${position.latitude},${position.longitude}";
    String typeMsg = realTime ? "[RASTREO ACTIVO]" : "[UBICACIÓN FIJA]";
    String msg = "¡SOS HUAYCO! Soy $userName. $typeMsg: $mapsLink";

    int successCount = 0;
    for (String number in recipients) {
      try {
        await platform.invokeMethod('sendDirectSMS', {"phone": number, "msg": msg});
        successCount++;
      } catch (e) { debugPrint("❌ Error SMS: $e"); }
    }

    if (mounted && successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Alerta enviada a $successCount contactos."), backgroundColor: Colors.green));
    }
  }

  // --- 6. CÁMARA (REPORTE) ---
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 50
      );

      if (photo != null) {
        if (!mounted) return;
        _showPhotoConfirmationDialog(File(photo.path));
      }
    } catch (e) {
      debugPrint("Error cámara: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo acceder a la cámara")));
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
            const Text("¿Deseas enviar esta foto al centro de monitoreo?"),
            const SizedBox(height: 10),
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(image: FileImage(imageFile), fit: BoxFit.cover),
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
            label: const Text("ENVIAR"),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ Reporte enviado al monitoreo central"), backgroundColor: Colors.green)
              );
            },
          ),
        ],
      ),
    );
  }

  // --- 7. SIMULACIÓN Y SENSORES ---
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
        _showNotification("⚠️ PRECAUCIÓN", "Nivel del río subiendo.");
        _startVibrationPattern(isRedAlert: false);
        _showCautionDialog();
        _checkPermissionsForWarning();
      } else if (alertLevel == 2) {
        vibrationIntensity = 7.8;
        etaHuayco = "IMPACTO EN 15 MIN";
        _showNotification("🚨 PELIGRO: HUAYCO", "¡Evacúa inmediatamente!");
        _startVibrationPattern(isRedAlert: true);
        if (autoSend) _sendSOS(isAuto: true);
        _showEmergencyDialog();
      }
    });
  }

  void _startVibrationPattern({required bool isRedAlert}) {
    _stopVibration();
    int counter = 0;
    int maxDuration = isRedAlert ? 10 : 5;

    if (isRedAlert) {
      _triggerVibrate();
      _vibrationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        counter += 3;
        if (counter >= maxDuration) _stopVibration(); else _triggerVibrate();
      });
    } else {
      _vibrationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        counter++;
        if (counter >= (maxDuration * 2)) _stopVibration(); else Vibrate.feedback(FeedbackType.warning);

      });
    }
  }

  void _triggerVibrate() async {
    if (await Vibrate.canVibrate) Vibrate.vibrateWithPauses([const Duration(milliseconds: 100), const Duration(milliseconds: 1000)]);
  }




  void _stopVibration() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  }

  // --- CARGA DE DATOS ---
  void _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? "Usuario";
      sosEnabled = prefs.getBool('sos_enabled') ?? true;
      autoSend = prefs.getBool('sos_auto_send') ?? false;
      realTime = prefs.getBool('sos_realtime') ?? false;
    });
    if (realTime) _startLocationStream();
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

  void _showCautionDialog() {
    showDialog(context: context, barrierDismissible: false, builder: (context) => AlertDialog(
      backgroundColor: Colors.orange[50],
      title: const Text("⚠️ PRECAUCIÓN"),
      content: const Text("Actividad inusual detectada."),
      actions: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), onPressed: () {_stopVibration(); Navigator.pop(context);}, child: const Text("ACEPTAR", style: TextStyle(color: Colors.white)))],
    ));
  }

  void _showEmergencyDialog() {
    showDialog(context: context, barrierDismissible: false, builder: (context) => AlertDialog(
      backgroundColor: Colors.red[50],
      title: const Text("¡ALERTA ROJA!"),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Huayco inminente. ETA: $etaHuayco."),
        const SizedBox(height: 10),
        if (autoSend) const Text("✅ Alerta enviada automáticamente.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))
        else const Text("⚠️ Presiona SOS para enviar alerta.", style: TextStyle(fontWeight: FontWeight.bold)),
      ]),
      actions: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () {_stopVibration(); Navigator.pop(context);}, child: const Text("ENTENDIDO"))],
    ));
  }

  void _showPermissionWarningDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("Permisos Faltantes"),
      content: const Text("Se requieren permisos para que el sistema funcione."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white), onPressed: () {Navigator.pop(context); _requestAllPermissions(); openAppSettings();}, child: const Text("SOLUCIONAR")),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      // 1. MENÚ LATERAL (COMPONENTE)
      drawer: const SideMenu(),

      // 2. BARRA SUPERIOR
      appBar: AppBar(
        title: const Text("Monitor Apu Waqay"),
        backgroundColor: getStatusColor(),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, size: 28),
            tooltip: "Guía de Seguridad",
            onPressed: () {
              // COMPONENTE: GUÍA DE SEGURIDAD
              showDialog(
                  context: context,
                  builder: (context) => const SafetyGuideDialog()
              );
            },
          ),
          IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: _simulateChange,
              tooltip: "Simular Alerta"
          ),
        ],
      ),

      // 3. BOTONES FLOTANTES
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
                highlightElevation: 0,
                splashColor: Colors.transparent,
                onPressed: _showPermissionWarningDialog,
                child: const Icon(Icons.warning_amber, color: Colors.amber, size: 40),
              ),
            ),
          ],
          FloatingActionButton(
            heroTag: "btn_camara",
            onPressed: _takePhoto,
            backgroundColor: Colors.white,
            tooltip: "Reportar Huayco (Foto)",
            child: const Icon(Icons.camera_alt, color: Colors.black87, size: 28),
          ),
          const SizedBox(width: 15),
          if (sosEnabled)
            FloatingActionButton.extended(
              heroTag: "btn_sos",
              onPressed: _handleSosPress,
              backgroundColor: alertLevel == 0 ? Colors.grey : Colors.red[900],
              icon: const Icon(Icons.sos, color: Colors.white, size: 30),
              label: Text(alertLevel == 0 ? "SOS (Info)" : "SOS", style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),

      // 4. CUERPO
      body: Column(
        children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: getStatusColor(), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)), boxShadow: [BoxShadow(color: getStatusColor().withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))]),
            child: Column(children: [
              Icon(alertLevel == 2 ? Icons.campaign : Icons.verified_user, size: 80, color: Colors.white),
              const SizedBox(height: 10),
              Text(getStatusText(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              if (alertLevel == 2) Text("LLEGADA ESTIMADA: $etaHuayco", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(onPressed: () => Navigator.pushNamed(context, AppRoutes.map), icon: const Icon(Icons.people_alt), label: const Text("Ver Ubicaciones Compartidas"), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.white, foregroundColor: Colors.black87)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              child: GridView.count(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, children: [
                // COMPONENTE: TARJETA DE SENSOR
                SensorCard(title: "Nivel Río", value: alertLevel == 2 ? "4.5 m" : "1.2 m", unit: "Metros", icon: Icons.waves, isCritical: alertLevel == 2),
                SensorCard(title: "Lluvia", value: alertLevel == 2 ? "120 mm" : "0 mm", unit: "Acumulada", icon: Icons.cloud, isCritical: alertLevel == 2),
                SensorCard(title: "Vibración", value: vibrationIntensity.toString(), unit: "Intensidad", icon: Icons.vibration, isCritical: vibrationIntensity > 5),
                SensorCard(title: "Rastreo", value: _isTracking ? "ACTIVO" : "INACTIVO", unit: "GPS", icon: _isTracking ? Icons.radar : Icons.location_disabled, isCritical: false),
              ]),
            ),
          )
        ],
      ),
    );
  }
}