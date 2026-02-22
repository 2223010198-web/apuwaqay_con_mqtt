import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- NUEVA IMPORTACIÓN
import '../../../app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- VARIABLES DE ESTADO Y CONTROLADORES ---
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dniController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    // BUENA PRÁCTICA: Liberar recursos de los controladores cuando la pantalla se destruye
    _nameController.dispose();
    _dniController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ==========================================================
  // LÓGICA DE NEGOCIO Y SERVICIOS
  // ==========================================================

  // 1. Verifica si el usuario ya se registró antes (Offline Support)
  void _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('isRegistered') == true && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  // 2. Simula el envío del SMS
  void _sendVerificationCode() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Simular delay de red
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _isLoading = false;
        _codeSent = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Código enviado: 1234 (Simulado)")),
        );
      }
    }
  }

  // 3. Verifica el código SMS y orquesta el registro (Cloud + Local)
  void _verifyAndLogin() async {
    if (_otpController.text.trim() == "1234") {
      setState(() => _isLoading = true);

      try {
        // PASO A: Crear usuario en la base de datos central (Requiere Internet)
        await _registerUserInFirebase();

        // PASO B: Guardar datos en el celular (Para funcionamiento sin Internet)
        await _saveDataLocally();

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.home);

      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Error de conexión. Necesitas internet para tu primer registro."),
              backgroundColor: Colors.red[800],
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Código incorrecto"), backgroundColor: Colors.red),
      );
    }
  }

  // --- SUB-FUNCIONES DE GUARDADO ---

  Future<void> _registerUserInFirebase() async {
    final db = FirebaseFirestore.instance;
    final phone = _phoneController.text.trim();

    // Usamos el número de celular como ID único del documento
    await db.collection('usuarios').doc(phone).set({
      'nombre': _nameController.text.trim(),
      'dni': _dniController.text.trim(),
      'celular': phone,
      'contactos_sos': [], // Inicialmente sin contactos agregados
      'ubicacion_actual': null,
      'ultima_actualizacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)); // 'merge' evita borrar datos si el usuario desinstala y reinstala
  }

  Future<void> _saveDataLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', _nameController.text.trim());
    await prefs.setString('userDni', _dniController.text.trim());
    await prefs.setString('userPhone', _phoneController.text.trim());
    await prefs.setBool('isRegistered', true);

    // Valores por defecto para la configuración SOS
    await prefs.setBool('sos_enabled', true);
    await prefs.setBool('sos_auto_send', false);
    await prefs.setBool('sos_realtime', false);
  }

  // ==========================================================
  // CONSTRUCCIÓN DE LA INTERFAZ (UI)
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (!_codeSent)
                      _buildRegistrationForm()
                    else
                      _buildVerificationForm(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- COMPONENTES VISUALES ---

  Widget _buildHeader() {
    return Container(
      height: 250,
      decoration: const BoxDecoration(
        color: Color(0xFFCF0A2C),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(60)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', width: 70, height: 70),
            const SizedBox(height: 10),
            const Text("APU WAQAY", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const Text("Registro de Usuario", style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: _inputDeco("Nombre Completo", Icons.person),
          validator: (v) => v!.isEmpty ? 'Requerido' : null,
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: _dniController,
          keyboardType: TextInputType.number,
          decoration: _inputDeco("DNI", Icons.badge),
          validator: (v) => v!.length != 8 ? 'DNI inválido' : null,
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: _inputDeco("Celular", Icons.phone),
          validator: (v) => v!.length < 9 ? 'Celular inválido' : null,
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendVerificationCode,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCF0A2C)),
            child: _isLoading
                ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : const Text("VERIFICAR NÚMERO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationForm() {
    return Column(
      children: [
        const Text("Se envió un SMS a tu número.", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 5),
          decoration: _inputDeco("Código SMS (1234)", Icons.lock_clock),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyAndLogin,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: _isLoading
                ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : const Text("CONFIRMAR Y ENTRAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey[600]),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCF0A2C), width: 2),
      ),
    );
  }
}