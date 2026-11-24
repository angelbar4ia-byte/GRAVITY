/// El perfil de la bicicleta de una persona (`hab_bici_perfil`, 5.2): una fila
/// con los valores editables, la lista de preparación y la marca de «Entendido»
/// de la línea fija.
library;

import 'preparacion.dart';
import 'reglas_bici.dart';
import 'tipos_bici.dart';

class PerfilBici {
  const PerfilBici({
    this.bicicletaActivaId,
    this.reglas = const ReglasBicicleta(),
    this.preparacion = const PreparacionPersonal(),
    this.avisoVistoEn,
  });

  final String? bicicletaActivaId;

  /// Duración prevista, margen, tope, carga de piernas y meta mensual.
  final ReglasBicicleta reglas;
  final PreparacionPersonal preparacion;

  /// Cuándo tocó «Entendido» (null hasta entonces: se muestra la línea fija).
  final DateTime? avisoVistoEn;

  bool get debeMostrarAviso => avisoVistoEn == null;

  List<ErrorBici> validar() => [
    for (final e in reglas.validar()) ErrorBici('regla_fuera_de_rango', e),
  ];

  /// Fila de `hab_bici_perfil`. `persona_id` lo pone el servidor. Los
  /// intervalos de agua y comida son de la V2 y no existen aquí.
  Map<String, Object?> aJson() => {
    'bicicleta_activa_id': bicicletaActivaId,
    'duracion_prevista_min': reglas.duracionPrevistaMin,
    'margen_revision_min': reglas.margenRevisionMin,
    'carga_piernas': reglas.cargaPiernas.id,
    'tope_aumento_pct': reglas.topeAumentoPct,
    'preparacion': preparacion.aJson(),
    'aviso_visto_en': avisoVistoEn?.toUtc().toIso8601String(),
  };
}
