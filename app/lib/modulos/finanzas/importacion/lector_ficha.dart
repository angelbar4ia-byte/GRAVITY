/// Lector de `FICHA_DEUDAS_Y_TARJETAS.xlsx` (Fase 2, 5.3 bis): las hojas
/// **Tarjetas**, **Credito_Auto** y **MSI** producen tarjetas, un crédito y
/// compras a meses para una vista previa que la persona confirma. Las hojas de
/// beneficios y estados de cuenta no se importan en esta fase.
///
/// El archivo es **entrada hostil**: se lee con `tablaDeArchivo` (mismos topes
/// que la plantilla de categorías, sin fórmulas ni enlaces externos) y no se
/// inventa nada: lo que falta se omite y se explica. Una fila de la ficha sin
/// saldo (las prellenadas con solo beneficios) **no** se importa.
library;

import 'dart:typed_data';

import 'package:finanzas_dominio/finanzas_dominio.dart';

import 'lector_xlsx.dart';

const _tope = 10 * 1000 * 1000 * 100; // 10 millones de pesos, en centavos

/// Algo de la ficha que no se importó, con su motivo.
class FilaOmitida {
  const FilaOmitida(this.hoja, this.fila, this.motivo);

  final String hoja;
  final int fila;
  final String motivo;
}

class TarjetaFicha {
  const TarjetaFicha({
    required this.idFicha,
    required this.institucion,
    required this.nombre,
    required this.saldo,
    this.limite,
    this.tasaPb,
    this.catPb,
    this.corteDia,
    this.limitePagoDia,
    this.minimo,
  });

  final String idFicha;
  final String institucion;
  final String nombre;
  final int saldo;
  final int? limite;
  final int? tasaPb;
  final int? catPb;
  final int? corteDia;
  final int? limitePagoDia;
  final int? minimo;
}

class CreditoFicha {
  const CreditoFicha({
    required this.institucion,
    required this.saldo,
    this.montoOriginal,
    this.tasaPb,
    this.permitePagoAnticipado,
    this.mensualidad,
    this.diaPago,
  });

  final String institucion;
  final int saldo;
  final int? montoOriginal;
  final int? tasaPb;
  final bool? permitePagoAnticipado;
  final int? mensualidad;
  final int? diaPago;
}

class MsiFicha {
  const MsiFicha({
    required this.idFicha,
    required this.comercio,
    required this.total,
    required this.meses,
    required this.pagadas,
    required this.fechaCompra,
    this.idTarjeta,
    this.descripcion,
  });

  final String idFicha;
  final String? idTarjeta;
  final String comercio;
  final String? descripcion;
  final int total;
  final int meses;
  final int pagadas;
  final Fecha fechaCompra;
}

class LecturaFicha {
  const LecturaFicha({
    this.tarjetas = const [],
    this.msi = const [],
    this.credito,
    this.omitidas = const [],
  });

  final List<TarjetaFicha> tarjetas;
  final List<MsiFicha> msi;
  final CreditoFicha? credito;
  final List<FilaOmitida> omitidas;

  bool get vacia => tarjetas.isEmpty && msi.isEmpty && credito == null;
}

// ------------------------------------------------------------------ valores

String _norm(String s) => normalizarNombre(s);

/// Centavos de "$1,500.50" o "1500.5"; `null` si no es un monto válido.
int? centavosDeCelda(String texto) {
  final limpio = texto.replaceAll(RegExp(r'[\s$]'), '').replaceAll(',', '');
  if (limpio.isEmpty) return null;
  final v = double.tryParse(limpio);
  if (v == null || !v.isFinite || v < 0) return null;
  final c = (v * 100).round();
  return c > _tope ? null : c;
}

/// Puntos base de "45", "45 %" o 0.45 (una celda con formato de porcentaje
/// guarda la fracción: si no trae "%" y es 1 o menos, se toma como fracción).
int? puntosBaseDeCelda(String texto) {
  final conPorcentaje = texto.contains('%');
  final limpio = texto.replaceAll(RegExp(r'[\s%]'), '').replaceAll(',', '.');
  if (limpio.isEmpty) return null;
  final v = double.tryParse(limpio);
  if (v == null || !v.isFinite || v < 0) return null;
  final pct = (!conPorcentaje && v <= 1) ? v * 100 : v;
  final pb = (pct * 100).round();
  return pb > 100000 ? null : pb;
}

int? _dia(String texto) {
  final v = double.tryParse(texto.trim());
  if (v == null || v != v.roundToDouble()) return null;
  final n = v.toInt();
  return n >= 0 && n <= 31 ? n : null;
}

Fecha? _fecha(String texto) {
  final t = texto.trim();
  try {
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(t);
    if (m != null) {
      return Fecha(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    }
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(t);
    if (iso != null) {
      return Fecha(int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!));
    }
    final serie = double.tryParse(t);
    if (serie != null && serie > 30000 && serie < 80000) {
      final d = DateTime.utc(1899, 12, 30).add(Duration(days: serie.floor()));
      return Fecha(d.year, d.month, d.day);
    }
  } catch (_) {
    return null;
  }
  return null;
}

String _celda(List<String> fila, int i) => i < fila.length ? fila[i].trim() : '';

String? _texto(String s) => s.isEmpty ? null : s;

/// Primera fila de la tabla cuyo primer campo es "ID" (el encabezado).
int _encabezado(List<List<String>> t) {
  for (var i = 0; i < t.length; i++) {
    if (_norm(_celda(t[i], 0)) == 'id') return i;
  }
  return -1;
}

List<List<String>>? _hoja(Uint8List bytes, String nombre, String hoja) {
  try {
    return tablaDeArchivo(bytes, nombreArchivo: nombre, hoja: hoja);
  } on ErrorArchivo catch (e) {
    // Una hoja que falta se explica; un archivo dañado, no.
    if (e.mensaje.startsWith('El archivo no tiene la hoja')) return null;
    rethrow;
  }
}

/// Lee la ficha. Lanza [ErrorArchivo] si el archivo no es válido o no es la
/// ficha (ninguna de las tres hojas).
LecturaFicha leerFichaDeBytes(Uint8List bytes, {required String nombre}) {
  if (bytes.length > maximoBytesDeImportacion) {
    throw const ErrorArchivo('El archivo pesa más de 10 MB: no es la ficha.');
  }
  if (!nombre.toLowerCase().endsWith('.xlsx')) {
    throw const ErrorArchivo('La ficha es un archivo .xlsx.');
  }
  try {
    final omitidas = <FilaOmitida>[];
    final tarjetas = <TarjetaFicha>[];
    final msi = <MsiFicha>[];
    CreditoFicha? credito;

    final hT = _hoja(bytes, nombre, 'Tarjetas');
    final hC = _hoja(bytes, nombre, 'Credito_Auto');
    final hM = _hoja(bytes, nombre, 'MSI');
    if (hT == null && hC == null && hM == null) {
      throw const ErrorArchivo(
        'El archivo no parece la ficha: faltan las hojas Tarjetas, '
        'Credito_Auto y MSI.',
      );
    }

    if (hT != null) {
      final e = _encabezado(hT);
      for (var i = e + 1; e >= 0 && i < hT.length; i++) {
        final f = hT[i];
        final id = _celda(f, 0);
        if (id.isEmpty || _norm(id) == 'ejemplo') continue;
        final saldo = centavosDeCelda(_celda(f, 6));
        if (saldo == null) {
          omitidas.add(FilaOmitida('Tarjetas', i + 1, '$id: sin saldo actual (captúralo en la ficha).'));
          continue;
        }
        final institucion = _celda(f, 1);
        if (institucion.isEmpty) {
          omitidas.add(FilaOmitida('Tarjetas', i + 1, '$id: sin institución.'));
          continue;
        }
        tarjetas.add(
          TarjetaFicha(
            idFicha: id,
            institucion: institucion,
            nombre: _celda(f, 2),
            saldo: saldo,
            limite: centavosDeCelda(_celda(f, 5)),
            tasaPb: puntosBaseDeCelda(_celda(f, 7)),
            catPb: puntosBaseDeCelda(_celda(f, 8)),
            corteDia: _dia(_celda(f, 9)),
            limitePagoDia: _dia(_celda(f, 10)),
            minimo: centavosDeCelda(_celda(f, 11)),
          ),
        );
      }
    }

    if (hC != null) {
      final valores = <String, String>{};
      for (var i = 4; i < hC.length; i++) {
        final etiqueta = _norm(_celda(hC[i], 0));
        final dato = _celda(hC[i], 1);
        if (etiqueta.isNotEmpty && dato.isNotEmpty) valores[etiqueta] = dato;
      }
      String? buscar(bool Function(String) f) {
        for (final e in valores.entries) {
          if (f(e.key)) return e.value;
        }
        return null;
      }

      final saldo = centavosDeCelda(buscar((k) => k.startsWith('saldo')) ?? '');
      if (saldo == null) {
        if (valores.isNotEmpty) {
          omitidas.add(const FilaOmitida('Credito_Auto', 0, 'Crédito automotriz: sin saldo actual.'));
        }
      } else {
        final anticipado = buscar((k) => k.contains('anticipado'));
        credito = CreditoFicha(
          institucion: buscar((k) => k.startsWith('institucion')) ?? 'Crédito automotriz',
          saldo: saldo,
          montoOriginal: centavosDeCelda(buscar((k) => k.startsWith('monto original')) ?? ''),
          tasaPb: puntosBaseDeCelda(buscar((k) => k.startsWith('tasa')) ?? ''),
          permitePagoAnticipado: anticipado == null
              ? null
              : switch (_norm(anticipado)) {
                  'si' || 'sí' => true,
                  'no' => false,
                  _ => null,
                },
          mensualidad: centavosDeCelda(buscar((k) => k.startsWith('mensualidad') || k.startsWith('pago mensual')) ?? ''),
          diaPago: _dia(buscar((k) => k.contains('dia de pago') || k.contains('dia limite')) ?? ''),
        );
      }
    }

    if (hM != null) {
      final e = _encabezado(hM);
      for (var i = e + 1; e >= 0 && i < hM.length; i++) {
        final f = hM[i];
        final id = _celda(f, 0);
        if (id.isEmpty || _norm(id) == 'ejemplo') continue;
        final total = centavosDeCelda(_celda(f, 5));
        final meses = int.tryParse(_celda(f, 6).replaceAll(RegExp(r'\.0+$'), ''));
        final fecha = _fecha(_celda(f, 4));
        final comercio = _celda(f, 2);
        String? falta;
        if (total == null || total <= 0) {
          falta = 'sin monto total';
        } else if (meses == null || meses < 2 || meses > 48) {
          falta = 'meses fuera de 2 a 48';
        } else if (fecha == null) {
          falta = 'sin fecha de compra';
        } else if (comercio.isEmpty) {
          falta = 'sin comercio';
        }
        if (falta != null) {
          omitidas.add(FilaOmitida('MSI', i + 1, '$id: $falta.'));
          continue;
        }
        final pagadas = int.tryParse(_celda(f, 8).replaceAll(RegExp(r'\.0+$'), '')) ?? 0;
        msi.add(
          MsiFicha(
            idFicha: id,
            idTarjeta: _texto(_celda(f, 1)),
            comercio: comercio,
            descripcion: _texto(_celda(f, 3)),
            total: total!,
            meses: meses!,
            pagadas: pagadas.clamp(0, meses),
            fechaCompra: fecha!,
          ),
        );
      }
    }
    return LecturaFicha(
      tarjetas: tarjetas,
      msi: msi,
      credito: credito,
      omitidas: omitidas,
    );
  } on ErrorArchivo {
    rethrow;
  } catch (_) {
    throw const ErrorArchivo(
      'No pude leer el archivo: está dañado o no es la ficha.',
    );
  }
}
