import 'package:flutter/material.dart';
import 'app_routes.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'data/services/global_alert_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';



/*
void main() {
  runApp(const ApuWaqayApp());
}
*/


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await GlobalAlertService().init();

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


 //     initialRoute: AppRoutes.splash,
      initialRoute: AppRoutes.login,
      routes: AppRoutes.routes,
    );
  }
}