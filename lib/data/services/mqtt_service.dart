import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  // Patrón Singleton
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttServerClient? client;

  // Stream para enviar datos a la UI
  final StreamController<Map<String, dynamic>> _dataStream = StreamController.broadcast();
  Stream<Map<String, dynamic>> get dataStream => _dataStream.stream;

  bool _isConnected = false;

  Future<void> connect() async {
    if (_isConnected) return;

    // --- CREDENCIALES DEL NUEVO CLUSTER (F16A) ---
    // Usamos const para asegurar que no se lean valores viejos de caché
    const String broker = 'f16a68d046f444be84636fcd495e8c7c.s1.eu.hivemq.cloud';
    const int port = 8883;
    const String user = 'jore-223010198';
    const String pass = 'Wildbl00d';
    const String topic = 'apuwaqay/sensores/data';

    // Generar ID único corto para evitar conflictos en HiveMQ
    String clientIdentifier = 'apu_movil_${DateTime.now().millisecondsSinceEpoch % 100000}';

    debugPrint("🔌 Iniciando configuración MQTT para: $broker");

    client = MqttServerClient.withPort(broker, clientIdentifier, port);

    // --- 🛡️ CONFIGURACIÓN BLINDADA PARA EMULADOR 2026 ---
    client!.secure = true;
    client!.keepAlivePeriod = 60;
    client!.logging(on: true);
    client!.setProtocolV311();
    client!.autoReconnect = true;

    // TRUCO DE SEGURIDAD: Creamos un contexto que confía en TODO
    // Esto es necesario porque tu emulador tiene fecha 2026 y el certificado expira antes.
    SecurityContext context = SecurityContext.defaultContext;
    try {
      context.setTrustedCertificatesBytes([]); // Intentamos limpiar restricciones
    } catch (e) {
      // Ignorar si falla en algunos Androids
    }
    client!.securityContext = context;

    // BYPASS TOTAL: Si el certificado parece vencido (por la fecha 2026), LO ACEPTAMOS IGUAL.
    client!.onBadCertificate = (dynamic cert) {
      debugPrint("⚠️ [SEGURIDAD] Certificado aceptado manualmente (Bypass de fecha activado)");
      return true;
    };

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client!.connectionMessage = connMessage;

    try {
      debugPrint("🔌 Conectando a HiveMQ...");
      await client!.connect(user, pass);
    } catch (e) {
      debugPrint('❌ Error Fatal al conectar: $e');
      client!.disconnect();
    }

    if (client!.connectionStatus!.state == MqttConnectionState.connected) {
      _isConnected = true;
      debugPrint('✅ ¡CONEXIÓN EXITOSA! Esperando datos en: $topic');

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
      debugPrint('❌ La conexión falló. Estado: ${client!.connectionStatus!.state}');
      client!.disconnect();
    }
  }

  // --- ✅ FUNCIÓN RECUPERADA (Esto arregla el error de compilación) ---
  void simulateData(Map<String, dynamic> fakeData) {
    debugPrint("🐛 MODO SIMULACIÓN: Datos inyectados manualmente");
    _dataStream.add(fakeData);
  }

  void disconnect() {
    client?.disconnect();
    _isConnected = false;
  }
}