import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

// --- TUS DATOS DE EMQX ---
const String server = 'u21e1123.ala.us-east-1.emqxsl.com';
const int port = 8883; // Puerto SSL Estándar
const String username = 'jore-223010198';
const String password = 'Wildbl00d';

void main() {
  runApp(const MaterialApp(home: TestScreen()));
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});
  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  String status = "Esperando orden...";
  Color statusColor = Colors.black;
  List<String> logs = [];

  void addLog(String message) {
    print(message); // Imprimir en consola también
    setState(() {
      logs.add("• $message");
      // Mantenemos solo los últimos 15 logs en pantalla
      if (logs.length > 15) logs.removeAt(0);
    });
  }

  Future<void> testSSLConnection() async {
    setState(() {
      status = "⏳ Probando SSL (8883)...";
      statusColor = Colors.blue;
      logs.clear();
    });

    // Generamos un ID corto y simple para evitar rechazos
    String clientIdentifier = 'test_apu_001';

    addLog("Configurando cliente para: $server");
    addLog("Usuario: $username");

    final client = MqttServerClient.withPort(server, clientIdentifier, port);

    // 1. CONFIGURACIÓN SSL ESTRICTA
    client.secure = true;
    client.keepAlivePeriod = 60;
    client.logging(on: true);
    client.setProtocolV311();

    // 2. CONTEXTO DE SEGURIDAD + BYPASS DE FECHA
    // Esto es vital para tu emulador con fecha 2026.
    client.securityContext = SecurityContext.defaultContext;

    // Callback para ignorar errores de certificado vencido (por la fecha incorrecta)
    client.onBadCertificate = (dynamic cert) {
      addLog("⚠️ ALERTA: Certificado inválido detectado (Probablemente por la fecha 2026).");
      addLog("👉 APLICANDO BYPASS... Aceptando conexión.");
      return true; // <--- ESTO FUERZA LA CONEXIÓN
    };

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMessage;

    try {
      addLog("🚀 Iniciando Handshake SSL...");
      await client.connect(username, password);
    } catch (e) {
      addLog("❌ EXCEPCIÓN: $e");
      setState(() {
        status = "❌ Error de Conexión";
        statusColor = Colors.red;
      });
      client.disconnect();
      return;
    }

    // 3. VERIFICAR RESULTADO
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      addLog("✅ ¡Handshake completado!");
      setState(() {
        status = "✅ CONEXIÓN EXITOSA";
        statusColor = Colors.green;
      });

      // Prueba de suscripción para asegurar flujo de datos
      client.subscribe("apuwaqay/sensores/data", MqttQos.atMostOnce);
      addLog("📡 Suscrito al tópico de sensores (Prueba final)");

      await Future.delayed(const Duration(seconds: 3));
      client.disconnect();
      addLog("🔌 Desconectado exitosamente.");
    } else {
      addLog("❌ Falló la autenticación o conexión.");
      setState(() {
        status = "❌ Estado: ${client.connectionStatus!.state}";
        statusColor = Colors.red;
      });
      client.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Diagnóstico MQTT SSL")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              width: double.infinity,
              decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor, width: 2)
              ),
              child: Text(status,
                style: TextStyle(color: statusColor, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.network_check),
              label: const Text("INICIAR PRUEBA"),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)
              ),
              onPressed: testSSLConnection,
            ),
            const SizedBox(height: 20),
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("LOGS EN VIVO:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                color: Colors.black87,
                child: ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(logs[index], style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.greenAccent)),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}