/// Lo que Ajustes › Voz sabe de este equipo: qué voces hay, cuáles sirven y
/// por qué no sirve una fuente. Todo sale del motor de voz; nada se inventa.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../gravity/voz/fuente_de_voz.dart';
import '../../gravity/voz/motor.dart';
import '../../gravity/voz/proveedores.dart';
import '../../gravity/voz/tipos.dart';

/// Foto de las voces de este equipo.
class InformeVoz {
  const InformeVoz({
    required this.asistente,
    required this.vocesEnEspanol,
    required this.vocesEnIngles,
    required this.sistema,
  });

  /// Qué fuentes sirven para que el asistente hable en español.
  final Disponibilidad asistente;

  /// Voces locales en español de la voz del dispositivo (primero las `es-MX`).
  final List<VozMotor> vocesEnEspanol;

  /// Voces locales en inglés, por acento (solo americano y británico).
  final Map<Variante, List<VozMotor>> vocesEnIngles;

  /// Todas las voces que reporta el sistema, también las que no se ofrecen.
  final List<VozDelSistema> sistema;

  /// La voz del dispositivo no está en este equipo (plataforma sin ella).
  bool get plataformaSinVoz =>
      asistente.descartadas[Fuente.dispositivo] ==
      Motivo.plataformaNoSoportada;

  /// El equipo no tiene motor de voz o no responde.
  bool get sinMotor =>
      asistente.descartadas[Fuente.dispositivo] == Motivo.sinMotorDeVoz;

  /// Hay una voz del dispositivo que sirve para el asistente.
  bool get dispositivoServiblePara =>
      asistente.cadena.contains(Fuente.dispositivo);

  int get totalEnIngles =>
      vocesEnIngles.values.fold(0, (suma, voces) => suma + voces.length);

  /// Voces que el sistema dice que necesitan conexión: no se ofrecen (R8).
  int get vocesDeRed => sistema.where((v) => v.requiereRed == true).length;

  /// Voces cuyos datos no están instalados: no se ofrecen.
  int get vocesSinInstalar => sistema.where((v) => !v.instalada).length;
}

/// Se vuelve a calcular al abrir la pantalla y con "Actualizar".
final informeVozProvider = FutureProvider.autoDispose<InformeVoz>((ref) async {
  final MotorVoz motor = ref.watch(motorVozProvider);
  final asistente = await motor.disponibilidad(
    UsoVoz.asistente,
    variante: Variante.esMX,
  );
  final espanol = await motor.voces(Fuente.dispositivo, variante: Variante.esMX);
  final ingles = {
    for (final v in const [Variante.enUS, Variante.enGB])
      v: await motor.voces(Fuente.dispositivo, variante: v),
  };
  final sistema = await motor.diagnostico(Fuente.dispositivo);
  return InformeVoz(
    asistente: asistente,
    vocesEnEspanol: espanol,
    vocesEnIngles: ingles,
    sistema: sistema,
  );
});
