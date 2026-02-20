import 'package:flutter/material.dart';
import 'dart:math' as math;

class EmergencyButton extends StatefulWidget {
  final int alertLevel; // 0: Verde, 1: Naranja, 2: Rojo
  final bool sosEnabled;
  final VoidCallback onConfigure; // Acción para ir a ajustes
  final Future<void> Function() onSendManualSos; // Acción para enviar el SMS

  const EmergencyButton({
    super.key,
    required this.alertLevel,
    required this.sosEnabled,
    required this.onConfigure,
    required this.onSendManualSos,
  });

  @override
  State<EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<EmergencyButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Controlador de la animación de "campana" (temblor rápido)
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    // Rotación leve de izquierda a derecha
    _animation = Tween<double>(begin: -0.03, end: 0.03).animate(_controller);

    if (widget.alertLevel == 2) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(EmergencyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Iniciar o detener la animación si el estado cambia
    if (widget.alertLevel == 2 && oldWidget.alertLevel != 2) {
      _controller.repeat(reverse: true);
    } else if (widget.alertLevel != 2 && oldWidget.alertLevel == 2) {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePress() {
    if (widget.alertLevel == 0) {
      _showGreenDialog();
    } else if (widget.alertLevel == 1) {
      _showOrangeDialog();
    } else {
      _showRedDialog();
    }
  }

  // --- ESTADO VERDE: Deshabilitado visualmente, solo informa ---
  void _showGreenDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [Icon(Icons.info_outline, color: Colors.blue, size: 32), SizedBox(width: 10), Text("Botón SOS")],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("El botón está inactivo porque te encuentras en una zona segura.", textAlign: TextAlign.justify),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
              child: const Text("💡 Función:\nAl activarse una alerta, este botón enviará tu ubicación GPS por SMS a INDECI y a tus familiares.", style: TextStyle(color: Colors.blueGrey, fontSize: 13), textAlign: TextAlign.justify),
            ),
          ],
        ),
        actions: [
          TextButton.icon(onPressed: () { Navigator.pop(context); widget.onConfigure(); }, icon: const Icon(Icons.settings), label: const Text("Configurar Contactos")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context), child: const Text("ENTENDIDO")),
        ],
      ),
    );
  }

  // --- ESTADO NARANJA: Alerta temprana, refuerza importancia y permite enviar ---
  void _showOrangeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32), SizedBox(width: 10), Text("Precaución SOS")],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("El nivel del río está subiendo. Si te sientes en peligro, puedes enviar tu ubicación ahora mismo.", textAlign: TextAlign.justify),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
              child: const Text("⚠️ Importante:\nVe a Configuración y activa el 'Envío Automático'. Así, la app pedirá ayuda por ti a INDECI y familiares si ocurre el huayco, aunque no puedas tocar el celular.", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.justify),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton.icon(onPressed: () { Navigator.pop(context); widget.onConfigure(); }, icon: const Icon(Icons.settings), label: const Text("Configurar")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () { Navigator.pop(context); widget.onSendManualSos(); },
              child: const Text("ENVIAR AHORA")
          ),
        ],
      ),
    );
  }

  // --- ESTADO ROJO: Peligro inminente, botón directo ---
  void _showRedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [Icon(Icons.sos, color: Colors.red, size: 32), SizedBox(width: 10), Text("¡ALERTA ROJA!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))],
        ),
        content: const Text("¿Deseas enviar un SMS de emergencia con tu ubicación GPS a INDECI y a tus contactos ahora mismo?", textAlign: TextAlign.justify, style: TextStyle(fontSize: 16)),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              onPressed: () { Navigator.pop(context); widget.onSendManualSos(); },
              child: const Text("SÍ, ENVIAR SOS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.sosEnabled) return const SizedBox.shrink();

    // En estado 0 (Verde) el botón se ve gris/deshabilitado
    Color buttonColor = widget.alertLevel == 0 ? Colors.grey : Colors.red.shade900;

    return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.rotate(
            // Si está en estado 2 (Rojo), aplica la rotación de la campana
            angle: widget.alertLevel == 2 ? _animation.value * math.pi : 0,
            child: FloatingActionButton.extended(
              heroTag: "btn_sos",
              onPressed: _handlePress,
              backgroundColor: buttonColor,
              icon: const Icon(Icons.sos, color: Colors.white),
              label: const Text("SOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          );
        }
    );
  }
}