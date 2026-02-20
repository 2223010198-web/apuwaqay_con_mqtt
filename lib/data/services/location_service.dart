import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? lastKnownPosition;

  bool get isTracking => _positionStreamSubscription != null;

  // --- RECUPERADO: Petición explícita y validación de permisos GPS ---
  Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Validar si el servicio GPS del celular está encendido
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('El servicio de ubicación está deshabilitado.');
      return false;
    }

    // 2. Verificar permisos de la app
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 3. Pedir permiso al usuario
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Permisos de ubicación denegados por el usuario.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Permisos de ubicación denegados permanentemente.');
      return false;
    }

    return true; // Permisos concedidos
  }

  Future<void> startTracking({required Function(Position) onPositionUpdate}) async {
    if (isTracking) return;

    // Exigimos permisos antes de rastrear
    bool hasPermission = await requestPermission();
    if (!hasPermission) return;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Notifica cambios cada 10 metros
    );

    try {
      _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen((Position position) {
        lastKnownPosition = position;
        onPositionUpdate(position);
        debugPrint("📍 Rastreo Activo: ${position.latitude}, ${position.longitude}");
      });
    } catch (e) {
      debugPrint("Error iniciando rastreo GPS: $e");
    }
  }

  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  Future<Position?> getCurrentOrLastPosition() async {
    bool hasPermission = await requestPermission();
    if (!hasPermission) return null;

    // Si la última posición es reciente (menos de 2 minutos), la usamos para ahorrar batería y tiempo
    if (lastKnownPosition != null && DateTime.now().difference(lastKnownPosition!.timestamp).inMinutes < 2) {
      return lastKnownPosition;
    }

    try {
      // Intentamos obtener la ubicación exacta
      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5) // Límite para no bloquear la app
      );
    } catch (e) {
      debugPrint("Error obteniendo GPS actual, usando última conocida: $e");
      return await Geolocator.getLastKnownPosition();
    }
  }
}