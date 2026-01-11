import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Para guardar datos localmente
import '../../../app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dniController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // Verificar si ya se registró antes para saltar esta pantalla
  void _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool? isRegistered = prefs.getBool('isRegistered');
    if (isRegistered == true && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  void _saveAndLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Guardamos los datos en el celular (Memoria local)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', _nameController.text);
      await prefs.setString('userDni', _dniController.text);
      await prefs.setBool('isRegistered', true); // Marcamos que ya entró

      // Simulamos un pequeño delay estético
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // CABECERA
            Container(
              height: 300,
              decoration: const BoxDecoration(
                color: Color(0xFFCF0A2C),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(60)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Image.asset('assets/images/logo.png', width: 80, height: 80),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "APU WAQAY",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
                    ),
                    const Text("Registro de Brigadista / Usuario", style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // FORMULARIO
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: "Nombre Completo",
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) => value!.isEmpty ? 'Ingrese su nombre' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _dniController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "DNI / Identificación",
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) => value!.isEmpty ? 'Ingrese su DNI' : null,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Estos datos se usarán solo para identificarte en los mensajes de SOS.",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),

                    // BOTÓN INGRESAR
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveAndLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCF0A2C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("GUARDAR Y ENTRAR", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}