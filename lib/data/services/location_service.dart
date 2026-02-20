import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? lastKnownPosition;

  bool get isTracking => _positionStreamSubscription != null;

  void startTracking({required Function(Position) onPositionUpdate}) {
    if (isTracking) return;
    const LocationSettings locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);

    try {
      _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen((Position position) {
        lastKnownPosition = position;
        onPositionUpdate(position);
        debugPrint("📍 Rastreo Activo: ${position.latitude}, ${position.longitude}");
      });
    } catch (e) {
      debugPrint("Error iniciando rastreo: $e");
    }
  }

  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  Future<Position?> getCurrentOrLastPosition() async {
    // Si la última posición es de hace menos de 2 minutos, la usa (más rápido)
    if (lastKnownPosition != null && DateTime.now().difference(lastKnownPosition!.timestamp).inMinutes < 2) {
      return lastKnownPosition;
    }
    try {
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      debugPrint("Error GPS: $e");
      return null;
    }
  }
}