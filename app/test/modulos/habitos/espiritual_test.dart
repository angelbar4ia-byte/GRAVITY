import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_diario.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_lectura.dart';
import 'package:gravity/modulos/habitos/datos/biblia.dart';
import 'package:gravity/modulos/habitos/datos/documentos_sensibles.dart';
import 'package:gravity/modulos/habitos/datos/repositorio_agenda.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/sensibles/llaves_habitos.dart';
import 'package:gravity/nucleo/sensibles/sobres.dart';
import 'package:gravity/nucleo/sensibles/subida_diferida.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

// Texto FICTICIO de relleno: valida la estructura, no es ninguna versión.
Map<String, Object?> bibliaFalsa() => {
  'formato': 'gravity-biblia-v1',
  'version': 'prueba',
  'nombre': 'Prueba',
  'licencia': 'ficticia',
  'origen': 'ficticio',
  'libros': [
    for (var i = 0; i < 66; i++)
      [
        for (var c = 0; c < canon[i].capitulos; c++)
          ['versículo uno de ${i + 1}:${c + 1}', 'ÁRBOL del versículo dos'],
      ],
  ],
};

void main() {
  test('Biblia: carga, valida el canon y busca sin acentos', () {
    final b = BibliaJson.deBytesGzip(
      gzip.encode(utf8.encode(jsonEncode(bibliaFalsa()))),
    );
    expect(b.capitulo(43, 3)!.first, 'versículo uno de 43:3');
    expect(b.capitulo(43, 22), isNull);
    expect(b.buscar('arbol', maximo: 3).length, 3);
    expect(b.buscar('ab'), isEmpty);
    expect(b.licencia, 'ficticia');
    final p = pasaje(b, analizarReferencia('Juan 3:2')!)!;
    expect(p.single.$1, 2);
    expect(pasaje(b, analizarReferencia('Juan 3')!)!.length, 2);
  });

  test('Biblia: rechaza formato o canon incorrectos', () {
    expect(() => BibliaJson.deMapa({'formato': 'otro'}), throwsFormatException);
    final m = bibliaFalsa();
    (m['libros']! as List).removeLast();
    expect(() => BibliaJson.deMapa(m), throwsFormatException);
  });

  test(
    'lectura: crear plan con fecha propia, hecho y ponerse al día',
    () async {
      var ahora = DateTime.utc(2026, 11, 2, 9);
      final repo = RepositorioAgendaEnMemoria();
      final s = ServicioLectura(repo, ahora: () => ahora);
      final p = await s.crear(
        TipoPlan.rutaInicio,
        inicio: DateTime.utc(2026, 11, 2),
      );
      expect((await s.activos()).length, 1);
      expect(s.deHoy(p)!.dia.dia, 1);
      await s.marcarHecho(p, p.plan.dias[0]);
      ahora = DateTime.utc(2026, 11, 9, 9); // día 8; los días 2 a 7 sin leer
      var h = s.deHoy(p)!;
      expect(h.atrasados, 6);
      await s.ponerAlDiaEn(p, 6);
      h = s.deHoy(p)!;
      expect(h.atrasados, 0);
      expect(
        p.plan.dias.last.fecha,
        DateTime.utc(2026, 11, 22),
      ); // la fecha final no cambia
      expect(p.plan.avancePct(), lessThan(10));
    },
  );

  test('lectura: saltar y reiniciar no culpan', () async {
    var ahora = DateTime.utc(2026, 11, 9);
    final s = ServicioLectura(RepositorioAgendaEnMemoria(), ahora: () => ahora);
    final p = await s.crear(
      TipoPlan.rutaInicio,
      inicio: DateTime.utc(2026, 11, 2),
    );
    await s.saltar(p);
    expect(
      p.plan.dias.take(7).every((d) => d.estado == EstadoDiaPlan.saltado),
      isTrue,
    );
    final q = await s.crear(TipoPlan.nt90, inicio: DateTime.utc(2026, 11, 2));
    await s.reiniciar(q);
    expect(q.plan.dias.first.fecha, DateTime.utc(2026, 11, 9));
  });

  test('segmentos del servidor son rangos consecutivos', () {
    final seg = PlanGuardado.segmentos(const [
      Capitulo(19, 1),
      Capitulo(19, 2),
      Capitulo(19, 3),
      Capitulo(20, 1),
    ]);
    expect(seg, [
      {'libro': 19, 'cap_ini': 1, 'cap_fin': 3},
      {'libro': 20, 'cap_ini': 1, 'cap_fin': 1},
    ]);
  });

  group('diario (sensible)', () {
    late AlmacenSeguroEnMemoria almacen;
    late ServicioDiario d;
    setUp(() {
      almacen = AlmacenSeguroEnMemoria();
      d = ServicioDiario(
        DocumentosSensibles(
          llaves: LlavesHabitos(almacen),
          sobres: AlmacenDeSobres(almacen),
          modos: ModosLocales(almacen),
          persona: 'ana',
          ahora: () => DateTime.utc(2026, 11, 3, 8),
        ),
        ahora: () => DateTime.utc(2026, 11, 3, 8),
      );
    });

    test(
      'peticiones: pendiente, en espera, respondida; nada en claro',
      () async {
        await d.agregarPeticion(
          'Por mi familia SECRETO_ORACION',
          categoria: 'familia',
        );
        var l = await d.peticiones();
        expect(l.single.estado, EstadoPeticion.pendiente);
        await d.cambiarEstado(l.single, EstadoPeticion.enEspera);
        await d.cambiarEstado(
          (await d.peticiones()).single,
          EstadoPeticion.respondida,
          nota: 'llegó',
        );
        l = await d.peticiones();
        expect(l.single.estado, EstadoPeticion.respondida);
        expect(l.single.respondida, isNotNull);
        expect(almacen.datos.values.join(), isNot(contains('SECRETO_ORACION')));
        expect(() => d.agregarPeticion('  '), throwsArgumentError);
      },
    );

    test('devocional, minutos de oración y notas', () async {
      await d.guardarDevocional(
        pasaje: 'Juan 1',
        reflexion: 'r',
        aplicacion: 'a',
        oracion: 'o',
      );
      final e = await d.devocionalDe(DateTime.utc(2026, 11, 3));
      expect(e!.pasaje, 'Juan 1');
      expect(e.breve, isFalse);
      await d.registrarOracion(10);
      await d.registrarOracion(5);
      expect(await d.minutosDeOracion(DateTime.utc(2026, 11, 3)), 15);
      await d.guardarNota(
        '43:3:16-16',
        'nota NOTA_PRIVADA',
        version: 'rvr1909',
      );
      expect(
        (await d.notasDe(DateTime.utc(2026, 11, 3))).single['texto'],
        contains('NOTA_PRIVADA'),
      );
      expect(almacen.datos.values.join(), isNot(contains('NOTA_PRIVADA')));
    });
  });
}
