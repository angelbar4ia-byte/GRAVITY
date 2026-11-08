/// Gasto desde un recibo fotografiado (Fase 8, bloque 4; D3, D19).
///
/// - El **texto** del recibo ya lo leyó el teléfono (plataforma, sin nube) y
///   llega en [ReciboImagen]; aquí no se lee ninguna imagen ni se llama a la
///   red. La foto viaja solo como bytes.
/// - [proponerGastoDeRecibo] solo **propone** (monto, concepto, fecha): lo que
///   no se encuentra queda en `null`, no se inventa.
/// - Nada se guarda sin confirmación: [confirmarGastoDeRecibo] es lo único que
///   escribe, y solo lo llama el botón *Guardar* de la hoja.
/// - La foto queda como **comprobante** del gasto en el teléfono de quien lo
///   registró ([ComprobanteLocal]); no sube a ninguna nube. La implementación
///   real (archivos del teléfono) es de plataforma; aquí hay una en memoria.
library;

import 'dart:typed_data';

import 'package:finanzas_dominio/finanzas_dominio.dart';

import '../pantallas/comunes.dart' show centavosDeTexto;
import 'servicio_finanzas.dart';

/// Un recibo fotografiado: la foto y el texto que el teléfono ya leyó.
abstract interface class ReciboImagen {
  /// La foto (bytes). Solo se guarda como comprobante en el teléfono.
  Uint8List get foto;

  /// Texto leído en el teléfono (puede venir vacío si no se pudo leer).
  String get textoLeido;
}

class ReciboImagenEnMemoria implements ReciboImagen {
  const ReciboImagenEnMemoria({required this.foto, required this.textoLeido});

  @override
  final Uint8List foto;
  @override
  final String textoLeido;
}

/// Dónde se guardan las fotos de los comprobantes: **solo en el teléfono** de
/// quien registró el gasto (supuesto del bloque 4). Se ligan por el id del
/// movimiento y por la persona.
abstract interface class ComprobanteLocal {
  Future<void> guardar({
    required String personaId,
    required String movimientoId,
    required Uint8List foto,
  });

  /// `null` si esa persona no tiene comprobante de ese movimiento.
  Future<Uint8List?> leer({
    required String personaId,
    required String movimientoId,
  });

  Future<void> borrar({
    required String personaId,
    required String movimientoId,
  });
}

/// Implementación en memoria (pruebas y demostración): se pierde al cerrar.
class ComprobanteLocalEnMemoria implements ComprobanteLocal {
  final Map<(String, String), Uint8List> _fotos = {};

  int get cantidad => _fotos.length;

  @override
  Future<void> guardar({
    required String personaId,
    required String movimientoId,
    required Uint8List foto,
  }) async => _fotos[(personaId, movimientoId)] = Uint8List.fromList(foto);

  @override
  Future<Uint8List?> leer({
    required String personaId,
    required String movimientoId,
  }) async => _fotos[(personaId, movimientoId)];

  @override
  Future<void> borrar({
    required String personaId,
    required String movimientoId,
  }) async => _fotos.remove((personaId, movimientoId));
}

/// Lo que se propone a la persona; cada dato puede faltar.
class PropuestaGasto {
  const PropuestaGasto({this.montoCentavos, this.concepto = '', this.fecha});

  final int? montoCentavos;
  final String concepto;
  final Fecha? fecha;
}

/// Un monto con centavos ("1,234.50" o "85.00"): sin centavos no se toma.
final _monto = RegExp(r'\d{1,3}(?:,\d{3})+\.\d{2}(?!\d)|\d+\.\d{2}(?!\d)');
final _fechaDmy = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})\b');
final _fechaIso = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');

/// Propone un gasto a partir del texto leído del recibo.
///
/// - **Monto:** el de la línea "total" (no "subtotal"); si no hay, el mayor
///   monto con centavos. Sin ninguno, `null`.
/// - **Concepto:** la primera línea con letras que no sea un monto, una fecha
///   ni una palabra de control (hasta 60 caracteres).
/// - **Fecha:** la primera fecha válida (dd/mm/aaaa o aaaa-mm-dd) que no sea
///   posterior a [hoy]; si no, `null`.
PropuestaGasto proponerGastoDeRecibo(String texto, Fecha hoy) {
  final lineas = [
    for (final l in texto.split(RegExp(r'[\r\n]+')))
      if (l.trim().isNotEmpty) l.trim(),
  ];
  int? monto;
  int? mayor;
  for (final l in lineas) {
    final minus = l.toLowerCase();
    if (l.contains(_fechaDmy) || l.contains(_fechaIso)) continue;
    for (final m in _monto.allMatches(l)) {
      final v = centavosDeTexto(m.group(0)!);
      if (v == null || v <= 0) continue;
      if (mayor == null || v > mayor) mayor = v;
      if (minus.contains('total') && !minus.contains('subtotal')) monto = v;
    }
  }
  monto ??= mayor;

  Fecha? fecha;
  for (final l in lineas) {
    final iso = _fechaIso.firstMatch(l);
    final dmy = _fechaDmy.firstMatch(l);
    final partes = iso != null
        ? [iso.group(1)!, iso.group(2)!, iso.group(3)!]
        : dmy != null
        ? [dmy.group(3)!, dmy.group(2)!, dmy.group(1)!]
        : null;
    if (partes == null) continue;
    try {
      final f = Fecha(
        int.parse(partes[0]),
        int.parse(partes[1]),
        int.parse(partes[2]),
      );
      if (!f.despuesDe(hoy)) {
        fecha = f;
        break;
      }
    } on ArgumentError {
      continue;
    } on FormatException {
      continue;
    }
  }

  const control = ['total', 'subtotal', 'iva', 'cambio', 'efectivo', 'folio'];
  var concepto = '';
  for (final l in lineas) {
    if (!RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]{3}').hasMatch(l)) continue;
    if (l.contains(_fechaDmy) || l.contains(_fechaIso)) continue;
    final minus = l.toLowerCase();
    if (control.any(minus.startsWith)) continue;
    concepto = l.length > 60 ? l.substring(0, 60) : l;
    break;
  }
  return PropuestaGasto(montoCentavos: monto, concepto: concepto, fecha: fecha);
}

/// Guarda el gasto **ya confirmado** por la persona y deja la foto como su
/// comprobante. Si el gasto no se guarda (error), no se guarda la foto. Es lo
/// único de este archivo que escribe.
Future<ResultadoRegistro> confirmarGastoDeRecibo({
  required ServicioFinanzas servicio,
  required ComprobanteLocal comprobantes,
  required String personaId,
  required ReciboImagen recibo,
  required String libroId,
  required String cuentaOrigenId,
  required int montoCentavos,
  required String concepto,
  required Fecha fecha,
  String? categoriaId,
  String? motivo,
}) async {
  final r = await servicio.registrarGasto(
    libroId: libroId,
    cuentaOrigenId: cuentaOrigenId,
    lineas: [LineaGasto(monto: montoCentavos, categoriaId: categoriaId)],
    fecha: fecha,
    nota: concepto,
    motivo: motivo,
    via: ViaCaptura.imagen,
  );
  await comprobantes.guardar(
    personaId: personaId,
    movimientoId: r.movimientos.first.id,
    foto: recibo.foto,
  );
  return r;
}
