class SimulationService {
  // Recibe el nivel actual y devuelve el siguiente nivel junto con datos simulados
  Map<String, dynamic> getNextSimulationState(int currentLevel) {
    // Ciclo matemático: 0 -> 1 -> 2 -> 0...
    int nextLevel = (currentLevel + 1) % 3;

    switch (nextLevel) {
      case 0: // ESTADO SEGURO (Verde)
        return {
          "rio": 1.2,
          "lluvia": 0.0,
          "vibracion": 0.0,
          "nivel_alerta": 0,
          "probabilidad": 0.05
        };
      case 1: // ESTADO DE PRECAUCIÓN (Naranja)
        return {
          "rio": 3.2,
          "lluvia": 45.0,
          "vibracion": 3.5,
          "nivel_alerta": 1,
          "probabilidad": 0.65
        };
      case 2: // ESTADO DE PELIGRO (Rojo)
        return {
          "rio": 5.5,
          "lluvia": 125.0,
          "vibracion": 8.2,
          "nivel_alerta": 2,
          "probabilidad": 0.98
        };
      default:
        return {
          "rio": 1.2,
          "lluvia": 0.0,
          "vibracion": 0.0,
          "nivel_alerta": 0,
          "probabilidad": 0.0
        };
    }
  }
}