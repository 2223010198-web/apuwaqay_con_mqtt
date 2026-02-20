import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MqttService {
  // Patrón Singleton: Una sola conexión en toda la app
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  late MqttServerClient client;

  // Stream global que todos (Dashboard y Background) pueden escuchar
  final StreamController<Map<String, dynamic>> _dataStream = StreamController.broadcast();
  Stream<Map<String, dynamic>> get dataStream => _dataStream.stream;

  bool _isConnected = false;

  Future<void> connect() async {
    if (_isConnected) return; // Si ya está conectado (en segundo plano), no hace nada

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
      debugPrint('✅ MQTT Conectado (Global)');
      client.subscribe(topic, MqttQos.atMostOnce);

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        try {
          final data = jsonDecode(pt);
          _dataStream.add(data); // Envía los datos al flujo
        } catch (e) {
          debugPrint("Error parseando JSON: $e");
        }
      });
    }
  }

  // Permite al botón del Dashboard inyectar datos simulados como si vinieran de internet
  void simulateData(Map<String, dynamic> fakeData) {
    _dataStream.add(fakeData);
  }

  void disconnect() {
    client.disconnect();
    _isConnected = false;
  }
}