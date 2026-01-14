import 'package:flutter/material.dart';
import 'app_routes.dart';

void main() {
  runApp(const ApuWaqayApp());
}

class ApuWaqayApp extends StatelessWidget {
  const ApuWaqayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apu Waqay',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFCF0A2C),
          primary: const Color(0xFFCF0A2C),
          secondary: Colors.amber,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),


      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}