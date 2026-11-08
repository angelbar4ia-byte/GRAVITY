import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/datos/imagen_telefono.dart';

class _RedProhibida extends HttpOverrides {
  int intentos = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    intentos++;
    throw StateError('sin red con la imagen');
  }
}

void main() {
  final foto = Uint8List.fromList([1, 2, 3, 4]);
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('gravity_img_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('la captura no pide permiso ni abre cámara al crearse', () {
    final c = CapturaReciboFalsa(foto);
    expect(c.tomas, 0);
    expect(c.disponible, isTrue);
  });

  test('la foto solo se toma al tocar "Fotografiar recibo"', () async {
    final c = CapturaReciboFalsa(foto);
    expect(await c.fotografiar(), foto);
    expect(c.tomas, 1);
  });

  test('en Windows no hay cámara', () async {
    const c = CapturaReciboSinCamara();
    expect(c.disponible, isFalse);
    expect(await c.fotografiar(), isNull);
  });

  test('el texto se lee localmente: sin llamadas de red con la imagen', () async {
    final red = _RedProhibida();
    final lector = LectorTextoFalso('TOTAL 120.50');
    final texto = await HttpOverrides.runWithHttpOverrides(
      () => lector.leer(foto),
      red,
    );
    expect(texto, 'TOTAL 120.50');
    expect(lector.imagenesRecibidas.single, foto);
    expect(red.intentos, 0);
  });

  test('el código real de imagen no usa red', () {
    final f = File('lib/modulos/finanzas/datos/imagen_telefono.dart');
    final codigo = f
        .readAsLinesSync()
        .where((l) => l.trimLeft().startsWith('import '))
        .join('\n');
    expect(codigo, isNot(contains('package:http')));
    expect(codigo, isNot(contains('supabase')));
    expect(codigo, isNot(contains('dio')));
  });

  test('el comprobante queda ligado al gasto y en la carpeta privada', () async {
    final c = ComprobanteLocalArchivos(Directory('${tmp.path}/comprobantes'));
    await c.guardar('gasto-1', foto);
    expect(await c.existe('gasto-1'), isTrue);
    expect(await c.existe('gasto-2'), isFalse);
    expect(await c.leer('gasto-1'), foto);
    expect(
      File('${tmp.path}/comprobantes/gasto-1.jpg').existsSync(),
      isTrue,
    );
    await c.borrar('gasto-1');
    expect(await c.existe('gasto-1'), isFalse);
  });

  test('un id con ruta no sale de la carpeta del comprobante', () async {
    final c = ComprobanteLocalArchivos(Directory('${tmp.path}/comprobantes'));
    expect(() => c.guardar('../fuera', foto), throwsArgumentError);
  });

  test('las páginas de estado de cuenta se leen y se borran', () async {
    final tem = Directory('${tmp.path}/estados');
    final lector = LectorTextoFalso('pág');
    final r = await PaginasEstadoCuenta(
      lector,
      temporal: tem,
    ).leerYBorrar([foto, foto]);
    expect(r, ['pág', 'pág']);
    expect(tem.listSync(), isEmpty);
  });

  test('las páginas se borran aunque falle la lectura', () async {
    final tem = Directory('${tmp.path}/estados');
    final malo = _LectorQueFalla();
    await expectLater(
      PaginasEstadoCuenta(malo, temporal: tem).leerYBorrar([foto]),
      throwsStateError,
    );
    expect(tem.listSync(), isEmpty);
  });
}

class _LectorQueFalla implements LectorTextoLocal {
  @override
  Future<String> leer(Uint8List imagen) async => throw StateError('falla');
}
