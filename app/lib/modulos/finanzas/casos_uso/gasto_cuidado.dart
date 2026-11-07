/// Paso de un gasto de cuidado a Finanzas (Fase 5, sección 1 y 10).
///
/// La cuidadora registra el gasto en Cuidados (`cui_gastos`, estado
/// `pendiente_confirmacion`). **Solo cuando el dueño lo confirma** pasa al
/// libro de Finanzas como un movimiento más (solo-agregar, centavos, cola sin
/// conexión):
///
/// - Gasto **de Papá**: va al libro representado de Papá, **en nombre de Papá**
///   (`enNombreDe`), capturado por el albacea que confirma, con motivo.
/// - Gasto **de la casa**: va al libro compartido (por ejemplo "Gastos de la
///   casa"); lo confirma un miembro vigente de ese libro.
///
/// La categoría es la de "Cuidados de largo plazo" del árbol; si el hogar no
/// la tiene, queda en "Por clasificar" (no se inventa una categoría).
///
/// Esta función es pura: no guarda nada. Quien confirma llama después a
/// `repositorio.agregarMovimientos([movimiento])`; el id es estable (UUID v5
/// de `cui_gastos.id`), así que reintentar no duplica (`ON CONFLICT (id) DO
/// NOTHING`). La app no mueve dinero sola: la acción es del dueño.
library;

import 'package:finanzas_dominio/finanzas_dominio.dart';

import '../datos/ids.dart';
import '../datos/repositorio.dart' show ErrorFinanzas;
import 'sugerencias.dart' show cuentasParaPagar;

/// Estados de `cui_gastos` que importan aquí.
enum EstadoGastoCuidado { pendienteConfirmacion, confirmado, rechazado }

/// Un gasto de cuidado tal como lo registra la cuidadora.
class GastoCuidado {
  const GastoCuidado({
    required this.id,
    required this.fecha,
    required this.centavos,
    required this.registradoPor,
    this.concepto = '',
    this.esDePapa = true,
    this.personaBajoCuidadoId,
    this.estado = EstadoGastoCuidado.pendienteConfirmacion,
  });

  /// `cui_gastos.id`.
  final String id;
  final Fecha fecha;

  /// Centavos, siempre positivo.
  final int centavos;

  /// Persona que lo registró (la cuidadora o la hermana).
  final String registradoPor;
  final String concepto;

  /// `true` si es de Papá; `false` si es de la casa.
  final bool esDePapa;

  /// La persona bajo cuidado (Papá): debe ser el titular del libro de destino.
  final String? personaBajoCuidadoId;
  final EstadoGastoCuidado estado;
}

/// Motivo que lleva el movimiento de un gasto de cuidado de Papá.
const motivoGastoCuidado = 'Gasto de cuidado confirmado';

/// Categoría de cuidado del árbol: la primera visible cuyo nombre es
/// "Cuidados de largo plazo…" (Salud › Cuidados de largo plazo y paliativos).
Categoria? categoriaDeCuidado(ArbolCategorias arbol) {
  for (final c in arbol.todas) {
    if (c.visible &&
        c.nivel > 1 &&
        normalizarNombre(c.nombre).contains('cuidados de largo plazo')) {
      return c;
    }
  }
  return null;
}

/// Arma el movimiento de Finanzas de [gasto], confirmado por [confirmadoPor]
/// en [confirmadoEn], dentro del libro [libroId] de [datos].
///
/// [cuentaOrigenId] es la cuenta con la que se pagó; por omisión, la primera de
/// [cuentasParaPagar] (efectivo antes que banco). Lanza [ErrorFinanzas] si el
/// gasto no está pendiente, el monto no es positivo, el libro no corresponde,
/// quien confirma no puede o no hay cuenta de pago.
Movimiento gastoDeCuidadoAFinanzas(
  GastoCuidado gasto, {
  required DatosFinanzas datos,
  required String libroId,
  required String confirmadoPor,
  required DateTime confirmadoEn,
  String? cuentaOrigenId,
}) {
  if (gasto.estado != EstadoGastoCuidado.pendienteConfirmacion) {
    throw const ErrorFinanzas(
      'Ese gasto de cuidado ya no está pendiente de confirmar.',
    );
  }
  if (gasto.centavos <= 0) {
    throw const ErrorFinanzas(
      'El gasto de cuidado necesita un monto mayor a 0.',
    );
  }
  final libro = datos.libro(libroId);
  if (libro == null) throw const ErrorFinanzas('No existe ese libro.');
  if (libro.archivado) {
    throw ErrorFinanzas('${libro.nombre} está archivado: ya no se registra.');
  }

  final dia = Fecha.deDateTime(confirmadoEn);
  final miembro = libro.miembros
      .where((m) => m.personaId == confirmadoPor && m.vigenteEn(dia))
      .firstOrNull;
  String realizadoPor = confirmadoPor;
  String? enNombreDe;
  String? motivo;
  if (gasto.esDePapa) {
    final papa = gasto.personaBajoCuidadoId;
    if (libro.tipo != TipoLibro.representado ||
        papa == null ||
        libro.titularId != papa) {
      throw const ErrorFinanzas(
        'El gasto de Papá va a su libro, que llevan sus albaceas.',
      );
    }
    if (miembro == null ||
        (miembro.papel != PapelLibro.albacea &&
            miembro.papel != PapelLibro.albaceaSuplente)) {
      throw const ErrorFinanzas(
        'Solo un albacea vigente de Papá confirma sus gastos de cuidado.',
      );
    }
    realizadoPor = papa;
    enNombreDe = papa;
    motivo = motivoGastoCuidado;
  } else {
    if (libro.tipo != TipoLibro.compartido) {
      throw const ErrorFinanzas(
        'El gasto de la casa va a un libro compartido (Gastos de la casa).',
      );
    }
    if (miembro == null) {
      throw const ErrorFinanzas('Solo un miembro del libro lo confirma.');
    }
  }

  final cuentaPago =
      cuentaOrigenId ?? cuentasParaPagar(datos, libroId).firstOrNull?.id;
  final origen = cuentaPago == null ? null : datos.cuenta(cuentaPago);
  if (origen == null ||
      origen.libroId != libroId ||
      (origen.clase != ClaseCuenta.activo &&
          origen.clase != ClaseCuenta.pasivo)) {
    throw const ErrorFinanzas('Elige una cuenta de este libro para pagar.');
  }

  final categoria = categoriaDeCuidado(datos.arbol);
  final cuentaGasto = categoria == null
      ? (datos.parametrosDe(libroId).cuentaPorClasificarId ??
            datos
                .cuentasDe(libroId)
                .where((c) => c.tipo == TipoCuenta.porClasificar)
                .firstOrNull
                ?.id)
      : datos.arbol.cuentaGastoDe(categoria.id);
  if (cuentaGasto == null) {
    throw const ErrorFinanzas('No hay cuenta de gasto para el cuidado.');
  }

  final concepto = gasto.concepto.trim();
  return Movimiento(
    id: idEstable(ClavesId.gastoCuidado(gasto.id)),
    tipo: TipoMovimiento.gasto,
    fecha: gasto.fecha,
    registradoEn: confirmadoEn,
    cuentaOrigenId: origen.id,
    cuentaDestinoId: cuentaGasto,
    monto: gasto.centavos,
    realizadoPor: realizadoPor,
    registradoPor: confirmadoPor,
    categoriaId: categoria?.id,
    nota: concepto.isEmpty
        ? null
        : (concepto.length > 200 ? concepto.substring(0, 200) : concepto),
    motivo: motivo,
    enNombreDe: enNombreDe,
  );
}
