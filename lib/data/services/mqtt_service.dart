import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttServerClient? client;
  final StreamController<Map<String, dynamic>> _dataStream = StreamController.broadcast();
  Stream<Map<String, dynamic>> get dataStream => _dataStream.stream;

  bool _isConnected = false;

  Future<void> connect() async {
    if (_isConnected) return;

    // 🔥 CORRECCIÓN CRÍTICA: Esquema completo + Ruta
    // 1. 'ws://' indica WebSocket Inseguro (Evita error de fecha 2026)
    // 2. '/mqtt' es la ruta obligatoria de EMQX para WebSockets
    const String broker = 'ws://broker.emqx.io/mqtt';

    const int port = 8083;
    const String topic = 'apuwaqay/2026/proyecto/data';

    String clientIdentifier = 'apu_android_${DateTime.now().millisecondsSinceEpoch % 10000}';

    debugPrint("🌐 Conectando a $broker en puerto $port...");

    client = MqttServerClient.withPort(broker, clientIdentifier, port);

    // --- CONFIGURACIÓN WEBSOCKETS ---
    client!.useWebSocket = true;
    client!.secure = false; // Sin SSL = Sin problemas de fecha
    client!.autoReconnect = true;
    client!.keepAlivePeriod = 60;

    // IMPORTANTE: Definir el protocolo WebSocket explícitamente
    client!.websocketProtocols = MqttClientConstants.protocolsSingleDefault;

    client!.logging(on: true);

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client!.connectionMessage = connMessage;

    try {
      // Conexión anónima (Broker público)
      await client!.connect();
    } catch (e) {
      debugPrint('❌ Error Conexión: $e');
      client!.disconnect();
    }

    if (client!.connectionStatus!.state == MqttConnectionState.connected) {
      _isConnected = true;
      debugPrint('✅ ¡CONECTADO (WebSockets)! Esperando datos del sensor...');

      client!.subscribe(topic, MqttQos.atMostOnce);

      client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        try {
          String cleanJson = pt.trim();
          debugPrint("📥 RECIBIDO: $cleanJson");
          final data = jsonDecode(cleanJson);
          _dataStream.add(data);
        } catch (e) {
          // Ignorar
        }
      });
    } else {
      debugPrint('❌ Desconectado. Estado: ${client!.connectionStatus!.state}');
      client!.disconnect();
    }
  }

  void simulateData(Map<String, dynamic> fakeData) {
    _dataStream.add(fakeData);
  }

  void disconnect() {
    client?.disconnect();
    _isConnected = false;
  }
}
