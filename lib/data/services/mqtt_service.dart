import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- IMPORTACIONES PARA EL SOS AUTOMÁTICO ---
import 'location_service.dart';
import 'sos_service.dart';

class MqttService {
  // Patrón Singleton: Una sola conexión por Isolate
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  late MqttServerClient client;
  final StreamController<Map<String, dynamic>> _dataStream = StreamController.broadcast();
  Stream<Map<String, dynamic>> get dataStream => _dataStream.stream;

  bool _isConnected = false;

  Future<void> connect() async {
    if (_isConnected) return;

    final String broker = dotenv.env['MQTT_BROKER'] ?? '';
    final String user = dotenv.env['MQTT_USER'] ?? '';
    final String pass = dotenv.env['MQTT_PASSWORD'] ?? '';
    final String topic = dotenv.env['MQTT_TOPIC'] ?? '';
    final int port = int.tryParse(dotenv.env['MQTT_PORT'] ?? '8883') ?? 8883;

    client = MqttServerClient(broker, 'apu_waqay_app_${DateTime.now().millisecondsSinceEpoch}');
    client.logging(on: false);
    client.keepAlivePeriod = 60;
    client.port = port;
    client.secure = true;
    client.setProtocolV311();

    final context = SecurityContext.defaultContext;
    client.securityContext = context;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('apu_waqay_app_${DateTime.now().millisecondsSinceEpoch}')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    client.connectionMessage = connMessage;

    try {
      await client.connect(user, pass);
    } catch (e) {
      debugPrint('Excepción MQTT: $e');
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      _isConnected = true;
      debugPrint('✅ MQTT Conectado');
      client.subscribe(topic, MqttQos.atMostOnce);

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        try {
          final data = jsonDecode(pt);
          _dataStream.add(data);

          // LÓGICA DE SEGUNDO PLANO: Evaluar si hay emergencia
          _evaluarEmergenciaAutomatica(data);
        } catch (e) {
          debugPrint("Error parseando JSON: $e");
        }
      });
    }
  }

  void simulateData(Map<String, dynamic> fakeData) {
    _dataStream.add(fakeData);
    // Evaluamos también en la simulación para poder hacer pruebas
    _evaluarEmergenciaAutomatica(fakeData);
  }

  void disconnect() {
    client.disconnect();
    _isConnected = false;
  }

  bool _isProcessingSos = false;

  // --- LÓGICA DE ALERTA AUTOMÁTICA EN BACKGROUND ---
  Future<void> _evaluarEmergenciaAutomatica(Map<String, dynamic> data) async {
    // 1. SI LA PUERTA ESTÁ CERRADA, IGNORAMOS EL MENSAJE INMEDIATAMENTE
    if (_isProcessingSos) return;

    int alertLevel = (data['nivel_alerta'] ?? 0 as num).toInt();
    if (alertLevel != 2) return;

    // 2. CERRAMOS LA PUERTA (Nadie más puede entrar a enviar SMS)
    _isProcessingSos = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      bool isAutoSendEnabled = prefs.getBool('sos_auto_send') ?? false;

      if (!isAutoSendEnabled) return; // Si la configuración está apagada, salimos

      int lastSent = prefs.getInt('last_sos_sent_time') ?? 0;
      int now = DateTime.now().millisecondsSinceEpoch;

      // SISTEMA ANTI-SPAM (1 SMS cada 10 minutos)
      if (now - lastSent > 600000) {
        // 3. ACTUALIZAMOS EL TIEMPO ANTES DE EMPEZAR EL ENVÍO (Vital)
        await prefs.setInt('last_sos_sent_time', now);

        debugPrint("🚨 [CERROJO ACTIVO] Huayco detectado. Evitando duplicados...");

        final locationService = LocationService();
        final sosService = SosService();
        String userName = prefs.getString('userName') ?? "Usuario";

        final position = await locationService.getCurrentOrLastPosition();
        await sosService.sendSOSAlert(
            position: position,
            userName: userName,
            isAuto: true,
            isTracking: locationService.isTracking
        );
        debugPrint("✅ [ALERTA AUTOMÁTICA] ÚNICO SMS enviado con éxito.");
      }
    } catch (e) {
      debugPrint("❌ Error crítico en envío automático: $e");
    } finally {
      // 4. ABRIMOS LA PUERTA (Solo se ejecuta cuando todo el proceso terminó o falló)
      // Como SharedPreferences ya guardó el tiempo, los próximos mensajes esperarán 10 min.
      _isProcessingSos = false;
    }
  }
}