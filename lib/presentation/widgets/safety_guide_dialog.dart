import 'package:flutter/material.dart';

class SafetyGuideDialog extends StatefulWidget {
  const SafetyGuideDialog({super.key});

  @override
  State<SafetyGuideDialog> createState() => _SafetyGuideDialogState();
}

class _SafetyGuideDialogState extends State<SafetyGuideDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _guideSteps = [
    { "title": "1. PREPÁRATE", "desc": "Identifica las rutas de evacuación y zonas seguras en zonas altas. Ten lista tu MOCHILA DE EMERGENCIA.", "icon": Icons.backpack, "color": Colors.orange },
    { "title": "2. ALERTA", "desc": "Si escuchas sirenas o notas subida del nivel del río, NO cruces el cauce y aléjate de las riberas inmediatamente.", "icon": Icons.notifications_active, "color": Colors.red },
    { "title": "3. EVACÚA", "desc": "Dirígete a los puntos de reunión seguros. Ayuda a niños, ancianos y personas con discapacidad.", "icon": Icons.directions_run, "color": Colors.blue },
    { "title": "4. MANTENTE A SALVO", "desc": "No regreses a tu casa hasta que las autoridades (INDECI) indiquen que el peligro ha pasado.", "icon": Icons.health_and_safety, "color": Colors.green },
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        height: 450,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("¿Qué hacer ante un Huayco?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _guideSteps.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final step = _guideSteps[index];
                  return Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: step['color'].withOpacity(0.1), shape: BoxShape.circle), child: Icon(step['icon'], size: 60, color: step['color'])),
                          const SizedBox(height: 20),
                          Text(step['title'], style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: step['color'])),
                          const SizedBox(height: 10),
                          Text(step['desc'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.4)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_guideSteps.length, (index) => Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: _currentPage == index ? 12 : 8, height: 8, decoration: BoxDecoration(color: _currentPage == index ? Colors.blue : Colors.grey[300], borderRadius: BorderRadius.circular(4))))),
            const SizedBox(height: 15),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { if (_currentPage < _guideSteps.length - 1) { _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn); } else { Navigator.pop(context); } }, child: Text(_currentPage < _guideSteps.length - 1 ? "SIGUIENTE" : "ENTENDIDO"))),
          ],
        ),
      ),
    );
  }
}