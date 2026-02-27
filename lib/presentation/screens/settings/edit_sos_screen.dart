// lib/presentation/screens/settings/edit_sos_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/services/global_alert_service.dart'; // 1️⃣ Importación del Orquestador

class EditSosScreen extends StatefulWidget {
  const EditSosScreen({super.key});

  @override
  State<EditSosScreen> createState() => _EditSosScreenState();
}

class _EditSosScreenState extends State<EditSosScreen> {
  final _contact1Controller = TextEditingController();
  final _contact2Controller = TextEditingController();

  bool _autoSend = false;
  bool _realTime = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _contact1Controller.dispose();
    _contact2Controller.dispose();
    super.dispose();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _contact1Controller.text = prefs.getString('sos_contact_1') ?? '';
      _contact2Controller.text = prefs.getString('sos_contact_2') ?? '';
      _autoSend = prefs.getBool('sos_auto_send') ?? false;
      _realTime = prefs.getBool('sos_realtime') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    await _saveDataLocally();
    await _syncWithFirebase();

    // 2️⃣ DISPARADOR REACTIVO DE PRODUCCIÓN
    // Obliga al Orquestador a evaluar los nuevos estados inmediatamente,
    // activando el GPS hacia Firebase o el SMS automático sin reiniciar la app.
    await GlobalAlertService().evaluateReactiveConditions();

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Configuración SOS Guardada exitosamente"))
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _saveDataLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sos_contact_1', _contact1Controller.text.trim());
    await prefs.setString('sos_contact_2', _contact2Controller.text.trim());
    await prefs.setBool('sos_auto_send', _autoSend);
    await prefs.setBool('sos_realtime', _realTime);
  }

  Future<void> _syncWithFirebase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? miCelular = prefs.getString('userPhone');

      if (miCelular != null && miCelular.isNotEmpty) {
        List<String> misContactos = [];
        final c1 = _contact1Controller.text.trim();
        final c2 = _contact2Controller.text.trim();

        if (c1.isNotEmpty) misContactos.add(c1);
        if (c2.isNotEmpty) misContactos.add(c2);

        await FirebaseFirestore.instance.collection('usuarios').doc(miCelular).update({
          'contactos_sos': misContactos,
        });
      }
    } catch (e) {
      debugPrint("Sincronización en la nube pendiente por falta de red: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Editar SOS"),
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.shield, color: Colors.indigo),
              title: Text("Destinatario Principal"),
              subtitle: Text("INDECI (Central de Emergencias)"),
              trailing: Icon(Icons.check_circle, color: Colors.green),
            ),
          ),
          const SizedBox(height: 20),
          const Text("Contactos Adicionales (SMS)", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            controller: _contact1Controller,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: "Contacto 1 (Celular)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_add)
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _contact2Controller,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: "Contacto 2 (Celular)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_add)
            ),
          ),
          const Divider(height: 40),
          SwitchListTile(
            title: const Text("Envío Automático"),
            subtitle: const Text("Enviar ubicación SMS automáticamente si hay PELIGRO de Huayco"),
            value: _autoSend,
            activeColor: const Color(0xFFCF0A2C),
            onChanged: (v) => setState(() => _autoSend = v),
          ),
          SwitchListTile(
            title: const Text("Ubicación en Tiempo Real"),
            subtitle: const Text("Compartir posición en el mapa (Requiere agregar el contacto y tener internet)"),
            value: _realTime,
            activeColor: Colors.blue,
            onChanged: (v) => setState(() => _realTime = v),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCF0A2C),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("GUARDAR CAMBIOS", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}