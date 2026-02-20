import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // Verifica si TODOS los permisos críticos están concedidos
  Future<bool> hasAllPermissions() async {
    bool loc = await Permission.location.isGranted;
    bool sms = await Permission.sms.isGranted;
    bool cam = await Permission.camera.isGranted;
    bool notif = await Permission.notification.isGranted;
    // Opcional, dependiendo si llamas por teléfono directamente
    // bool phone = await Permission.phone.isGranted;

    return loc && sms && cam && notif;
  }

  // Pide todos los permisos de golpe al iniciar la app
  Future<void> requestAllPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.sms,
      Permission.camera,
      Permission.notification,
      // Permission.phone, // Descomenta si lo usas
    ].request();

    if (kDebugMode) {
      print("Estado Permisos:");
      statuses.forEach((permission, status) {
        print("$permission: $status");
      });
    }
  }

  // Permite abrir los ajustes del celular si el usuario los denegó permanentemente
  Future<void> openSettings() async {
    await openAppSettings();
  }
}