// Importador de FICHA_DEUDAS_Y_TARJETAS.xlsx (Fase 2, 5.1 punto 14). La ficha
// de estas pruebas es FICTICIA: la arma la propia prueba; ninguna prueba abre
// `data/personal/`.
import 'dart:convert';
import 'dart:typed_data';

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_fase2.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/importacion/lector_ficha.dart';
import 'package:gravity/modulos/finanzas/importacion/lector_xlsx.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import '../../revision_calidad/ayuda_zip.dart';
import 'ayuda_finanzas.dart';

String _t(String ref, String v) =>
    '<c r="$ref" t="inlineStr"><is><t>$v</t></is></c>';
String _n(String ref, String v) => '<c r="$ref"><v>$v</v></c>';

String _fila(int n, List<(String, String)> celdas) =>
    '<row r="$n">${celdas.map((c) => c.$2.startsWith('#') ? _n('${c.$1}$n', c.$2.substring(1)) : _t('${c.$1}$n', c.$2)).join()}</row>';

String _hoja(List<String> filas) =>
    '<worksheet><sheetData>${filas.join()}</sheetData></worksheet>';

Uint8List _ficha({bool sinHojas = false}) {
  final tarjetas = _hoja([
    _fila(1, [('A', 'Tarjetas de crédito')]),
    _fila(4, [
      ('A', 'ID'), ('B', 'Institución'), ('C', 'Tarjeta'), ('F', 'Límite de crédito'),
      ('G', 'Saldo actual'), ('H', 'Tasa anual (%)'), ('J', 'Día de corte'),
      ('K', 'Día límite de pago'), ('L', 'Pago mínimo'),
    ]),
    _fila(5, [('A', 'EJEMPLO'), ('B', 'Banco Ejemplo'), ('G', '#99999')]),
    _fila(6, [('A', 'T01'), ('B', 'Banco Sin Saldo'), ('C', 'Clásica')]),
    _fila(7, [
      ('A', 'T02'), ('B', 'Banco Uno'), ('C', 'Oro'), ('F', '#50000'),
      ('G', '#12000.50'), ('H', '#45'), ('J', '#10'), ('K', '#28'), ('L', '#600'),
    ]),
  ]);
  final credito = _hoja([
    _fila(4, [('A', 'Campo'), ('B', 'Tu dato'), ('C', 'Ejemplo (inventado)')]),
    _fila(5, [('A', 'Institución'), ('B', 'Caja Ejemplo'), ('C', 'Otra Caja')]),
    _fila(6, [('A', 'Monto original'), ('B', '#180000')]),
    _fila(7, [('A', 'Saldo actual'), ('B', '#120000')]),
    _fila(8, [('A', 'Tasa anual (%)'), ('B', '#0.18')]),
  ]);
  final msi = _hoja([
    _fila(4, [
      ('A', 'ID'), ('B', 'ID de tarjeta'), ('C', 'Comercio'), ('D', 'Descripción'),
      ('E', 'Fecha de compra'), ('F', 'Monto total'), ('G', 'No. de mensualidades'),
      ('I', 'Mensualidades pagadas'),
    ]),
    _fila(5, [('A', 'EJEMPLO'), ('C', 'Tienda Ejemplo')]),
    _fila(6, [
      ('A', 'M01'), ('B', 'T02'), ('C', 'Tienda Uno'), ('D', 'Televisión'),
      ('E', '15/09/2026'), ('F', '#12000'), ('G', '#12'), ('I', '#2'),
    ]),
    _fila(7, [('A', 'M02'), ('C', 'Tienda Dos')]),
  ]);
  final hojas = sinHojas
      ? [('Otra', _hoja([_fila(1, [('A', 'x')])]))]
      : [('Tarjetas', tarjetas), ('Credito_Auto', credito), ('MSI', msi)];
  final wb =
      '<workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'
      '${[for (var i = 0; i < hojas.length; i++) '<sheet name="${hojas[i].$1}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
      '</sheets></workbook>';
  final rels =
      '<Relationships>${[for (var i = 0; i < hojas.length; i++) '<Relationship Id="rId${i + 1}" Target="worksheets/sheet${i + 1}.xml"/>'].join()}</Relationships>';
  return construirZip([
    EntradaZip('xl/workbook.xml', utf8.encode(wb)),
    EntradaZip('xl/_rels/workbook.xml.rels', utf8.encode(rels)),
    for (var i = 0; i < hojas.length; i++)
      EntradaZip('xl/worksheets/sheet${i + 1}.xml', utf8.encode(hojas[i].$2)),
  ]);
}

void main() {
  test('lee tarjetas, crédito y MSI; omite lo que no tiene saldo o monto', () {
    final l = leerFichaDeBytes(_ficha(), nombre: 'ficha.xlsx');
    expect(l.tarjetas, hasLength(1));
    final t = l.tarjetas.single;
    expect(t.idFicha, 'T02');
    expect(t.saldo, 1200050);
    expect(t.limite, 5000000);
    expect(t.tasaPb, 4500);
    expect(t.corteDia, 10);
    expect(t.limitePagoDia, 28);
    expect(t.minimo, 60000);
    expect(l.credito!.saldo, 12000000);
    // 0.18 sin "%" es una fracción: 18 %.
    expect(l.credito!.tasaPb, 1800);
    expect(l.credito!.permitePagoAnticipado, isNull);
    expect(l.msi, hasLength(1));
    expect(l.msi.single.fechaCompra, Fecha(2026, 9, 15));
    expect(l.msi.single.pagadas, 2);
    // T01 sin saldo y M02 incompleto se explican; EJEMPLO no cuenta.
    expect(l.omitidas.map((o) => o.hoja), containsAll(['Tarjetas', 'MSI']));
    expect(l.omitidas.any((o) => o.motivo.contains('T01')), isTrue);
  });

  test('un archivo que no es la ficha, o no es .xlsx, se rechaza sin detalles', () {
    expect(
      () => leerFichaDeBytes(_ficha(sinHojas: true), nombre: 'ficha.xlsx'),
      throwsA(isA<ErrorArchivo>()),
    );
    expect(
      () => leerFichaDeBytes(Uint8List.fromList([1, 2, 3]), nombre: 'ficha.xlsx'),
      throwsA(isA<ErrorArchivo>()),
    );
    expect(
      () => leerFichaDeBytes(_ficha(), nombre: 'ficha.csv'),
      throwsA(isA<ErrorArchivo>()),
    );
    expect(
      () => leerFichaDeBytes(
        Uint8List(maximoBytesDeImportacion + 1),
        nombre: 'ficha.xlsx',
      ),
      throwsA(isA<ErrorArchivo>()),
    );
  });

  test('montos y porcentajes de celda', () {
    expect(centavosDeCelda(r'$1,500.50'), 150050);
    expect(centavosDeCelda('-5'), isNull);
    expect(centavosDeCelda('abc'), isNull);
    expect(puntosBaseDeCelda('45 %'), 4500);
    expect(puntosBaseDeCelda('45'), 4500);
    expect(puntosBaseDeCelda('0.45'), 4500);
    expect(puntosBaseDeCelda('1e400'), isNull);
  });

  test('aplicar crea cuentas y deudas con ids derivados y reimportar no '
      'duplica', () async {
    final repo = repositorioDe(sesionDe(Rol.dueno));
    addTearDown(repo.cerrar);
    final base = servicioDe(repo, sesionDe(Rol.dueno));
    final svc = ServicioDeudasAhorro(base);
    const libro = IdsDemostracion.libroDueno;
    final l = leerFichaDeBytes(_ficha(), nombre: 'ficha.xlsx');
    final deudasAntes = repo.datos.deudasDe(libro).length;

    final r1 = await svc.aplicarFicha(libro, l);
    expect(r1.creadas, 3);
    final nuevas = repo.datos.deudasDe(libro).skip(deudasAntes).toList();
    expect(nuevas.map((d) => d.clase), unorderedEquals([ClaseDeuda.tarjeta, ClaseDeuda.credito, ClaseDeuda.msi]));
    final tarjeta = nuevas.firstWhere((d) => d.clase == ClaseDeuda.tarjeta);
    expect(saldoDeDeuda(repo.datos, tarjeta), 1200050);
    expect(repo.datos.cuenta(tarjeta.cuentaPasivoId!)!.limiteCentavos, 5000000);
    final credito = nuevas.firstWhere((d) => d.clase == ClaseDeuda.credito);
    expect(credito.permitePagoAnticipado, isNull);
    final msi = repo.datos.msiDe(libro).single;
    expect(msi.tarjetaDeudaId, tarjeta.id);
    // 12 meses de $1,000 y 2 pagadas: quedan $10,000.
    expect(saldoDeDeuda(repo.datos, nuevas.firstWhere((d) => d.clase == ClaseDeuda.msi)), 1000000);

    final cuentas = repo.datos.cuentas.length;
    final r2 = await svc.aplicarFicha(libro, l);
    expect(r2.creadas, 0);
    expect(r2.yaExistian, 3);
    expect(repo.datos.deudasDe(libro).length, deudasAntes + 3);
    expect(repo.datos.cuentas.length, cuentas);
  });
}
