/// Avisos que solo la app sabe calcular (Fase 4, E16; `fin_emitir_aviso`):
/// el **flujo negativo previsto** y el **abono bajo el mínimo**. Dart puro.
///
/// Cada aviso lleva solo el tipo del catálogo (texto discreto, sin dinero,
/// D3 y D20), el objeto al que se refiere y una **clave estable** (tipo +
/// objeto + semana): calcular otra vez lo mismo no crea un segundo aviso (el
/// servidor es idempotente por `(persona, clave)`).
library;

import 'alertas.dart';
import 'plan_guardado.dart' show EstadoSemana;
import 'seguimiento.dart';

/// Un aviso listo para emitir.
class AvisoPorEmitir {
  final TipoAlerta tipo;

  /// `libro` o `deuda` (los objetos que acepta `fin_emitir_aviso`).
  final String objetoTipo;
  final String objetoId;

  /// Minúsculas, dígitos y `_ : . -` (máximo 120), como exige el servidor.
  final String clave;

  const AvisoPorEmitir({
    required this.tipo,
    required this.objetoTipo,
    required this.objetoId,
    required this.clave,
  });

  @override
  String toString() => 'AvisoPorEmitir(${tipo.clave}, $objetoTipo, $clave)';
}

/// Clave de aviso válida para el servidor a partir de sus partes.
String claveDeAviso(TipoAlerta tipo, String objetoId, String semanaInicio) {
  final limpia = '${tipo.clave}:$objetoId:$semanaInicio'
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_:.\-]'), '-');
  return limpia.length > 120 ? limpia.substring(0, 120) : limpia;
}

/// Los avisos de la app que corresponden a la semana de [v] con lo que se
/// sabe hoy:
///
/// - `flujo_negativo`: el saldo del peor caso baja de cero algún día;
/// - `abono_bajo_minimo`: el abono real de una deuda queda debajo de su
///   mínimo (uno por deuda).
///
/// Una semana cerrada no emite nada (ya no hay nada que revisar).
List<AvisoPorEmitir> avisosPorEmitir(VistaSemana v) {
  if (v.estado == EstadoSemana.cerrada) return const [];
  final lunes = '${v.semana.inicio}';
  final lista = <AvisoPorEmitir>[];
  if (v.flujo.primerDiaEnRiesgo != null) {
    lista.add(
      AvisoPorEmitir(
        tipo: TipoAlerta.flujoNegativo,
        objetoTipo: 'libro',
        objetoId: v.libroId,
        clave: claveDeAviso(TipoAlerta.flujoNegativo, v.libroId, lunes),
      ),
    );
  }
  for (final a in v.real.abonosBajoMinimo) {
    lista.add(
      AvisoPorEmitir(
        tipo: TipoAlerta.abonoBajoMinimo,
        objetoTipo: 'deuda',
        objetoId: a.deuda.id,
        clave: claveDeAviso(TipoAlerta.abonoBajoMinimo, a.deuda.id, lunes),
      ),
    );
  }
  return lista;
}
