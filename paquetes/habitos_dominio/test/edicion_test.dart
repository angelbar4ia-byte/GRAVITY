import 'package:habitos_dominio/habitos_dominio.dart';
import 'package:test/test.dart';

void main() {
  group('validarBloque', () {
    List<String> v({
      String titulo = 'Inglés',
      String area = 'educacion',
      int inicio = 1140,
      int duracion = 30,
      int dias = 31,
      int? recordar,
    }) => validarBloque(
      titulo: titulo,
      area: area,
      inicioMin: inicio,
      duracionMin: duracion,
      dias: dias,
      recordarMin: recordar,
    );

    test('un bloque correcto no tiene errores', () => expect(v(), isEmpty));
    test('nombre vacío o muy largo', () {
      expect(v(titulo: '  '), isNotEmpty);
      expect(v(titulo: 'x' * 121), isNotEmpty);
    });
    test('área, hora, duración y días', () {
      expect(v(area: 'otra'), isNotEmpty);
      expect(v(inicio: 1440), isNotEmpty);
      expect(v(inicio: -1), isNotEmpty);
      expect(v(duracion: 4), isNotEmpty);
      expect(v(duracion: 1441), isNotEmpty);
      expect(v(dias: 0), isNotEmpty);
      expect(v(dias: 128), isNotEmpty);
      expect(v(recordar: 1441), isNotEmpty);
      expect(v(recordar: 0), isEmpty);
    });
  });

  test('validarEdicionObjetivo: días, área, meta y unidad', () {
    List<String> v({
      String area = 'salud',
      bool dias = false,
      int mascara = 127,
      int? meta,
      String? unidad,
    }) => validarEdicionObjetivo(
      area: area,
      porDiasDeSemana: dias,
      diasSemana: mascara,
      metaValor: meta,
      unidad: unidad,
    );
    expect(v(), isEmpty);
    expect(v(area: 'x'), isNotEmpty);
    expect(v(dias: true, mascara: 0), isNotEmpty);
    expect(v(dias: false, mascara: 0), isEmpty);
    expect(v(meta: 0), isNotEmpty);
    expect(v(unidad: 'u' * 21), isNotEmpty);
  });

  test('limpiarLista: sin vacíos ni repetidos, recorta y limita', () {
    expect(limpiarLista([' hija ', '', 'hija', 'salud']), ['hija', 'salud']);
    expect(limpiarLista(['a' * 300]).single.length, maxLargoElemento);
    expect(
      () => limpiarLista([for (var i = 0; i < 11; i++) 'm$i']),
      throwsArgumentError,
    );
  });

  test('marcas: seis colores y referencia libro:cap:ver', () {
    expect(coloresSubrayado.length, 6);
    expect(referenciaMarca(43, 3, 16), '43:3:16');
    expect(analizarReferenciaMarca('43:3:16')!.ver, 16);
    expect(analizarReferenciaMarca('43:3'), isNull);
    expect(analizarReferenciaMarca('x:3:16'), isNull);
    // el formato cabe en la restricción de la base de datos
    final re = RegExp(r'^[0-9]{1,2}:[0-9]{1,3}:[0-9]{1,3}(-[0-9]{1,3})?$');
    expect(re.hasMatch(referenciaMarca(66, 150, 176)), isTrue);
  });

  test('hitos: salen una sola vez y no hay hitos de salud', () {
    expect(hitosPorVer(0, hitosCigarrillo, {}), isEmpty);
    expect(hitosPorVer(8, hitosCigarrillo, {}), [1, 3, 7]);
    expect(hitosPorVer(8, hitosCigarrillo, {1, 3}), [7]);
    expect(hitosPorVer(8, hitosCigarrillo, {1, 3, 7}), isEmpty);
    expect(hitosPorVer(30, hitosAzucar, {}), [3, 7, 14, 30]);
    for (final d in [...hitosCigarrillo, ...hitosAzucar]) {
      final t = textoHito(d).toLowerCase();
      for (final p in [
        'salud', 'pulmon', 'pulmón', 'corazón', 'presión', 'riesgo',
        'cáncer', 'diabetes', 'mejora', ...MensajesHabitos.prohibidas,
      ]) {
        expect(t.contains(p), isFalse, reason: '$d: $p');
      }
    }
  });

  group('revisionDisponible (sábado 14:30, aviso 15 min)', () {
    bool d(DateTime ahora) => revisionDisponible(
      ahora: ahora,
      diaSemana: 6,
      horaMin: 870,
      avisoMin: 15,
    );
    test('antes del aviso no; desde el aviso sí', () {
      expect(d(DateTime.utc(2026, 11, 2, 9)), isFalse); // lunes
      expect(d(DateTime.utc(2026, 11, 7, 14, 14)), isFalse);
      expect(d(DateTime.utc(2026, 11, 7, 14, 15)), isTrue);
      expect(d(DateTime.utc(2026, 11, 8, 8)), isTrue); // domingo
    });
  });
}
