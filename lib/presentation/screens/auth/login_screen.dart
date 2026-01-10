import 'package:flutter/material.dart';
import '../../../app_routes.dart'; // Para navegar al Home

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    // 1. Validar que escribieron algo
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // 2. Simular tiempo de conexión al servidor (1.5 segundos)
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      // 3. Validar credenciales (Simuladas por ahora)
      // Puedes usar usuario: "admin" y clave: "1234"
      if (_userController.text == "admin" && _passController.text == "1234") {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Usuario o contraseña incorrectos"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // CABECERA CON CURVA Y LOGO
            Container(
              height: 300,
              decoration: const BoxDecoration(
                color: Color(0xFFCF0A2C), // Rojo Huawei
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(60),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/images/logo.png', // Tu logo
                        width: 80,
                        height: 80,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "APU WAQAY",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const Text(
                      "Acceso Seguro",
                      style: TextStyle(color: Colors.white70),
                    )
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
                      controller: _userController,
                      decoration: InputDecoration(
                        labelText: "Usuario / DNI",
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Ingrese su usuario';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passController,
                      obscureText: true, // Ocultar contraseña
                      decoration: InputDecoration(
                        labelText: "Contraseña",
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Ingrese su contraseña';
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),

                    // BOTÓN DE LOGIN
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCF0A2C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          "INGRESAR",
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        // Acción simulada de recuperar contraseña
                      },
                      child: const Text("¿Olvidaste tu contraseña?", style: TextStyle(color: Colors.grey)),
                    )
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