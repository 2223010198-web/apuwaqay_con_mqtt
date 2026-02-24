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

    // --- CREDENCIALES DIRECTAS (Para evitar errores de caché del .env) ---
    const String broker = 'f16a68d046f444be84636fcd495e8c7c.s1.eu.hivemq.cloud';
    const int port = 8883;
    const String user = 'jore-223010198';
    const String pass = 'Wildbl00d';
    const String topic = 'apuwaqay/sensores/data';

    // ID de cliente corto y único
    String clientIdentifier = 'apu_movil_v2_${DateTime.now().millisecondsSinceEpoch % 10000}';

    client = MqttServerClient.withPort(broker, clientIdentifier, port);

    // --- CONFIGURACIÓN CRÍTICA PARA HIVEMQ + FECHA INCORRECTA ---
    client!.secure = true;
    client!.keepAlivePeriod = 60;
    client!.logging(on: true);
    client!.setProtocolV311();
    client!.autoReconnect = true;

    // 🔥 FIX DEL TIEMPO: Esto obliga a la app a aceptar el certificado aunque tu celular esté en 2026
    client!.securityContext = SecurityContext.defaultContext;
    client!.onBadCertificate = (dynamic cert) {
      debugPrint("⚠️ ALERTA: Certificado SSL aceptado manualmente (Bypass de fecha)");
      return true;
    };

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean() // Sesión limpia para evitar colas viejas
        .withWillQos(MqttQos.atLeastOnce);

    client!.connectionMessage = connMessage;

    try {
      debugPrint("🔌 Intentando conectar a HiveMQ Cluster F16A...");
      await client!.connect(user, pass);
    } catch (e) {
      debugPrint('❌ Excepción Fatal MQTT: $e');
      client!.disconnect();
    }

    if (client!.connectionStatus!.state == MqttConnectionState.connected) {
      _isConnected = true;
      debugPrint('✅ ¡CONEXIÓN EXITOSA! Recibiendo datos de la Raspberry...');

      client!.subscribe(topic, MqttQos.atMostOnce);

      client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final String pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        try {
          String cleanJson = pt.trim();
          final data = jsonDecode(cleanJson);
          debugPrint("📥 DATO RECIBIDO: $data");
          _dataStream.add(data);
        } catch (e) {
          debugPrint("⚠️ Error leyendo JSON: $e");
        }
      });
    } else {
      debugPrint('❌ Falló la conexión. Estado: ${client!.connectionStatus!.state}');
      client!.disconnect();
    }
  }

  // --- FUNCIÓN QUE FALTABA (Soluciona el error rojo de compilación) ---
  void simulateData(Map<String, dynamic> fakeData) {
    debugPrint("🐛 MODO SIMULACIÓN: $fakeData");
    _dataStream.add(fakeData);
  }

  void disconnect() {
    client?.disconnect();
    _isConnected = false;
  }
}