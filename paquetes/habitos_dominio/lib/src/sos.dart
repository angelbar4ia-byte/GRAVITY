/// SOS "Tengo un antojo" (reglas 58 a 62). Textos propios, cortos y sin
/// consejo médico: el dueño los revisa (P8). Son datos, no código de pantalla.
enum PasoSos { pausa, queEs, tecnica, temporizador, registro, cierre }

const pasosSos = PasoSos.values;

class TextosSos {
  const TextosSos._();
  static const pausa = 'Respira. Las ganas pasan; casi siempre duran pocos '
      'minutos.';
  static const queEs = '¿Con qué es el antojo?';
  static const tecnica = 'Elige algo pequeño para estos minutos.';
  static const temporizador = 'Si en 10 minutos sigue, repetimos.';
  static const sigue = '¿Sigue el antojo?';
  static const registro = 'Si quieres, cuéntanos cómo fue (30 segundos).';
  static const cierreSuperado = 'Lo atravesaste. Eso suma.';
  static const cierreConsumo =
      'Una caída no borra lo avanzado. ¿Qué te ayudaría mañana?';
}

/// Técnicas cerradas (F.5). Las favoritas de la persona van primero.
const tecnicasSos = <String, String>{
  'respiracion': 'Respiración guiada',
  'agua': 'Beber agua',
  'caminar': 'Caminar 5 minutos',
  'masticar': 'Masticar algo sin azúcar',
  'apoyo': 'Llamar o escribir a alguien de apoyo',
  'versiculo': 'Un versículo y una oración corta',
};

List<String> ordenarTecnicas(List<String> favoritas) {
  final f = [for (final t in favoritas) if (tecnicasSos.containsKey(t)) t];
  return [...f, for (final t in tecnicasSos.keys) if (!f.contains(t)) t];
}

enum ResultadoAntojo { superado, consumo }

/// Sesión del SOS: temporizador de [minutos] (5 a 15), repetible.
class SesionSos {
  SesionSos({int minutos = 10}) : minutos = minutos.clamp(5, 15);
  final int minutos;
  PasoSos paso = PasoSos.pausa;
  int rondas = 1;
  ResultadoAntojo? resultado;

  void avanzar() {
    final i = paso.index;
    if (i < PasoSos.values.length - 1) paso = PasoSos.values[i + 1];
  }

  /// Al terminar el tiempo: sigue (otra ronda) o ya pasó (superado).
  void terminarTiempo({required bool sigue}) {
    if (sigue) {
      rondas++;
      paso = PasoSos.tecnica;
    } else {
      resultado = ResultadoAntojo.superado;
      paso = PasoSos.registro;
    }
  }

  void registrarConsumo() {
    resultado = ResultadoAntojo.consumo;
    paso = PasoSos.cierre;
  }
}

/// Versículos de ánimo propuestos (P9): solo referencias de RVR1909 y KJV
/// (dominio público); el texto sale del lector y se verifica contra el texto
/// importado. El dueño las revisa.
const versiculosAnimo = <String>[
  'Salmos 46:1',
  'Salmos 121:1-2',
  'Isaías 41:10',
  'Josué 1:9',
  'Filipenses 4:13',
  '1 Corintios 10:13',
  'Gálatas 5:22-23',
];

/// Versículo del día (regla 75): determinista por fecha.
String versiculoDelDia(DateTime f, List<String> lista) {
  final dias = DateTime.utc(f.year, f.month, f.day)
      .difference(DateTime.utc(2000, 1, 1))
      .inDays;
  return lista[dias % lista.length];
}
