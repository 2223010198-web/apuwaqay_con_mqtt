import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MqttService {
  final String _broker = dotenv.env['MQTT_BROKER'] ?? '';
  final String _user = dotenv.env['MQTT_USER'] ?? '';
  final String _pass = dotenv.env['MQTT_PASSWORD'] ?? '';
  final String _topic = dotenv.env['MQTT_TOPIC'] ?? '';
  final int _port = int.tryParse(dotenv.env['MQTT_PORT'] ?? '8883') ?? 8883;

  late MqttServerClient client;

  final StreamController<Map<String, dynamic>> _dataStream = StreamController.broadcast();
  Stream<Map<String, dynamic>> get dataStream => _dataStream.stream;

  MqttService() {
    client = MqttServerClient.withPort(_broker, 'apu_waqay_app_${DateTime.now().millisecondsSinceEpoch}', _port);
  }

  Future<void> connect() async {
    client.logging(on: true);
    client.keepAlivePeriod = 60;

    // 1. CONFIGURACIÓN CRÍTICA PARA HIVEMQ CLOUD EN DART
    // Tienes que usar explícitamente el protocolo V3.1.1
    client.setProtocolV311();

    // 2. SEGURIDAD ESTRICTA (TLS/SSL)
    client.secure = true;

    // Configurar el contexto de seguridad para confiar en HiveMQ
    final context = SecurityContext.defaultContext;
    client.securityContext = context;

    // ALGUNOS BROKERS FALLAN SI SE ENVÍA EL WILL MESSAGE DE FORMA INCORRECTA
    // Vamos a simplificar el mensaje de conexión inicial
    final connMessage = MqttConnectMessage()
        .withClientIdentifier('apu_waqay_app_${DateTime.now().millisecondsSinceEpoch}')
        .authenticateAs(_user, _pass) // La contraseña va aquí también en algunas versiones de la librería
        .startClean();

    client.connectionMessage = connMessage;

    try {
      debugPrint('Intentando conectar a $_broker en puerto $_port con SSL...');
      // Conectar usando el usuario y contraseña explícitos
      await client.connect(_user, _pass);
    } on NoConnectionException catch (e) {
      debugPrint('Excepción de conexión (Broker rechazó): $e');
      client.disconnect();
    } on SocketException catch (e) {
      debugPrint('Excepción de Socket (Error de red/SSL): $e');
      client.disconnect();
    } catch (e) {
      debugPrint('Excepción general: $e');
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      debugPrint('✅ MQTT Conectado a HiveMQ Cloud');

      client.subscribe(_topic, MqttQos.atMostOnce);

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        try {
          final data = jsonDecode(pt);
          _dataStream.add(data);
          debugPrint("📡 Dato recibido: $pt");
        } catch (e) {
          debugPrint("Error parseando JSON: $e");
        }
      });
    } else {
      debugPrint('❌ Falla conexión MQTT. Estado: ${client.connectionStatus!.state}');
      client.disconnect();
    }
  }

  void disconnect() {
    client.disconnect();
    _dataStream.close();
  }
}