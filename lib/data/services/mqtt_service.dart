
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // <--- IMPORTAR

class MqttService {
  // Leemos las variables del .env
  final String _broker = dotenv.env['MQTT_BROKER'] ?? 'localhost';
  final String _user = dotenv.env['MQTT_USER'] ?? '';
  final String _pass = dotenv.env['MQTT_PASSWORD'] ?? '';
  final String _topic = dotenv.env['MQTT_TOPIC'] ?? 'test/topic';
  // El puerto viene como String, hay que pasarlo a int
  final int _port = int.tryParse(dotenv.env['MQTT_PORT'] ?? '1883') ?? 1883;

  late MqttServerClient client;

  // Stream para enviar datos al Dashboard
  final StreamController<Map<String, dynamic>> _dataStream = StreamController.broadcast();
  Stream<Map<String, dynamic>> get dataStream => _dataStream.stream;

  MqttService() {
    // Inicializamos el cliente con el broker del .env
    client = MqttServerClient(_broker, 'apu_waqay_app_${DateTime.now().millisecondsSinceEpoch}');
  }

  Future<void> connect() async {
    client.logging(on: true);
    client.keepAlivePeriod = 20;
    client.port = _port; // <--- USAR PUERTO DEL .ENV
    client.onDisconnected = _onDisconnected;

    // Configuración segura (necesaria para muchos brokers con auth)
    client.secure = false;
    client.setProtocolV311();

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('apu_waqay_app')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    client.connectionMessage = connMessage;

    try {
      debugPrint('Intentando conectar a $_broker...');
      // Usamos USUARIO y CONTRASEÑA del .env
      await client.connect(_user, _pass);
    } catch (e) {
      debugPrint('Excepción MQTT: $e');
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      debugPrint('✅ MQTT Conectado');

      // Suscribirse al tópico del .env
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
    }
  }

  void _onDisconnected() {
    debugPrint('MQTT Desconectado');
  }
}
