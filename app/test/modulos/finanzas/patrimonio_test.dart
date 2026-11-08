// Objetivos, inversiones, bienes y previsión (Fase 8, bloque 3): avance del
// objetivo, origen capturado o verificado, rendimiento sin cálculo, vigencia
// por fecha de captura y reglas por cuenta (D19). Datos de ejemplo inventados.
import 'package:finanzas_dominio/finanzas_dominio.dart'
    show Fecha, Libro, OrigenDato, permisoEnLibro;
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/fuente_tablas.dart';
import 'package:gravity/modulos/finanzas/datos/patrimonio.dart';
import 'package:gravity/modulos/finanzas/pantallas/patrimonio/vista_patrimonio.dart'
    show apartadoSemanalDeBolsa;
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/permisos/permisos.dart' as permisos;
import 'package:finanzas_dominio/finanzas_dominio.dart' show AportacionAhorro;

import 'ayuda_finanzas.dart';

void main() {
  final hoy = Fecha(2026, 11, 9);
  const libro = 'libro-1';

  group('avance del objetivo', () {
    test('cuánto falta y en cuántas semanas (redondeo hacia arriba)', () {
      final a = avanceObjetivo(
        metaCentavos: 1000000,
        ahorrado: 250000,
        apartadoSemanal: 20000,
        fechaMeta: hoy.sumarDias(365),
        hoy: hoy,
      );
      expect(a.falta, 750000);
      expect(a.semanasParaAlcanzar, 38); // 37.5 -> 38
      expect(a.alcanzado, isFalse);
      expect(a.llegaATiempo, isTrue); // 52 semanas disponibles
    });

    test('semanas exactas no suman una de más', () {
      final a = avanceObjetivo(
        metaCentavos: 100000,
        ahorrado: 0,
        apartadoSemanal: 10000,
        fechaMeta: hoy.sumarDias(70),
        hoy: hoy,
      );
      expect(a.semanasParaAlcanzar, 10);
      expect(a.semanasHastaFecha, 10);
      expect(a.llegaATiempo, isTrue);
    });

    test('con el apartado actual no llega a la fecha', () {
      final a = avanceObjetivo(
        metaCentavos: 100000,
        ahorrado: 0,
        apartadoSemanal: 5000,
        fechaMeta: hoy.sumarDias(70),
        hoy: hoy,
      );
      expect(a.semanasParaAlcanzar, 20);
      expect(a.llegaATiempo, isFalse);
    });

    test('sin apartado no se inventa una estimación', () {
      final a = avanceObjetivo(
        metaCentavos: 100000,
        ahorrado: 1000,
        apartadoSemanal: 0,
        fechaMeta: hoy.sumarDias(70),
        hoy: hoy,
      );
      expect(a.semanasParaAlcanzar, isNull);
      expect(a.llegaATiempo, isNull);
    });

    test('sin fecha meta: semanas estimadas y sin "a tiempo"', () {
      final a = avanceObjetivo(
        metaCentavos: 100000,
        ahorrado: 0,
        apartadoSemanal: 5000,
        fechaMeta: null,
        hoy: hoy,
      );
      expect(a.semanasParaAlcanzar, 20);
      expect(a.semanasHastaFecha, isNull);
      expect(a.llegaATiempo, isNull);
    });

    test('un objetivo sin fecha se guarda y se lee', () async {
      final r = RepositorioPatrimonioEnMemoria();
      await r.guardarObjetivo(
        const Objetivo(
          id: 'o1',
          libroId: libro,
          nombre: 'Viaje de ejemplo',
          metaCentavos: 100000,
        ),
      );
      final o = (await r.objetivos(libro)).single;
      expect(o.fechaMeta, isNull);
    });

    test('meta alcanzada: falta 0 y 0 semanas', () {
      final a = avanceObjetivo(
        metaCentavos: 100000,
        ahorrado: 120000,
        apartadoSemanal: 0,
        fechaMeta: hoy.sumarDias(-5),
        hoy: hoy,
      );
      expect(a.falta, 0);
      expect(a.semanasParaAlcanzar, 0);
      expect(a.alcanzado, isTrue);
    });

    test('el apartado se lee de las aportaciones existentes, no se copia', () {
      AportacionAhorro ap(
        String id,
        String bolsa,
        int sug, {
        int aportado = 0,
      }) => AportacionAhorro(
        id: id,
        libroId: libro,
        semanaId: 's1',
        bolsaId: bolsa,
        sugerido: sug,
        aportado: aportado,
      );
      final aportaciones = [
        ap('a', 'viaje', 12000),
        ap('b', 'viaje-otro', 99999),
        ap('c', 'casa', 5000, aportado: 7000),
      ];
      expect(apartadoSemanalDeBolsa(aportaciones, 's1', 'viaje'), 12000);
      expect(apartadoSemanalDeBolsa(aportaciones, 's1', 'casa'), 7000);
      expect(apartadoSemanalDeBolsa(aportaciones, null, 'viaje'), 0);
      expect(apartadoSemanalDeBolsa(aportaciones, 's2', 'viaje'), 0);
    });
  });

  group('inversiones', () {
    test('capturada a mano es "Capturado"; leída del PDF, "Verificado"', () {
      final a = inversionCapturada(
        id: 'i1',
        libroId: libro,
        nombre: 'Fondo de ejemplo',
        saldoCentavos: 500000,
        fechaCaptura: hoy,
        rendimientoPuntosBase: 0,
      );
      final b = inversionLeidaDeEstado(
        id: 'i2',
        libroId: libro,
        estado: EstadoInversionLeido(
          nombre: 'Pagaré de ejemplo',
          saldoCentavos: 800000,
          fecha: hoy,
        ),
      );
      expect(a.origen, OrigenDato.capturado);
      expect(a.etiquetaOrigen, 'Capturado');
      expect(a.esVerificada, isFalse);
      expect(b.origen, OrigenDato.verificado);
      expect(b.etiquetaOrigen, 'Verificado');
    });

    test('lo capturado a mano nunca queda verificado', () {
      final i = inversionCapturada(
        id: 'i1',
        libroId: libro,
        nombre: 'X',
        saldoCentavos: 1,
        fechaCaptura: hoy,
        rendimientoPuntosBase: 0,
      );
      expect(i.esVerificada, isFalse);
    });

    test('el rendimiento se muestra tal como se capturó, sin cálculo', () {
      final i = inversionCapturada(
        id: 'i1',
        libroId: libro,
        nombre: 'X',
        saldoCentavos: 1000000,
        fechaCaptura: hoy,
        rendimientoPuntosBase: puntosBaseDeTexto('5.5'),
      );
      expect(i.rendimientoPuntosBase, 550);
      expect(i.rendimientoTexto, '5.50 %');
      // Otro saldo u otra fecha no cambian el rendimiento: no se deriva.
      final otra = Inversion(
        id: i.id,
        libroId: libro,
        nombre: i.nombre,
        saldoCentavos: 9999999,
        fechaCaptura: hoy.sumarDias(30),
        rendimientoPuntosBase: i.rendimientoPuntosBase,
      );
      expect(otra.rendimientoTexto, '5.50 %');
    });

    test('sin rendimiento no se guarda; con cero sí', () async {
      expect(
        () => inversionCapturada(
          id: 'i1',
          libroId: libro,
          nombre: 'X',
          saldoCentavos: 1000000,
          fechaCaptura: hoy,
          rendimientoPuntosBase: puntosBaseDeTexto(''),
        ),
        throwsArgumentError,
      );
      final cero = inversionCapturada(
        id: 'i2',
        libroId: libro,
        nombre: 'X',
        saldoCentavos: 1000000,
        fechaCaptura: hoy,
        rendimientoPuntosBase: puntosBaseDeTexto('0'),
      );
      expect(cero.rendimientoPuntosBase, 0);
      expect(cero.rendimientoTexto, '0.00 %');
      final r = RepositorioPatrimonioEnMemoria();
      await r.guardarInversion(cero);
      expect(await r.inversiones(libro), hasLength(1));
    });

    test('puntos base de texto', () {
      expect(puntosBaseDeTexto('5'), 500);
      expect(puntosBaseDeTexto('5,25 %'), 525);
      expect(puntosBaseDeTexto('12.05'), 1205);
      expect(puntosBaseDeTexto('5.555'), isNull);
      expect(puntosBaseDeTexto('abc'), isNull);
      expect(textoPuntosBase(5), '0.05');
    });

    test('lector de PDF no disponible: interfaz sin efecto', () async {
      const lector = LectorEstadoInversionNoDisponible();
      expect(lector.disponible, isFalse);
      expect(await lector.leer(), isNull);
    });

    test('el repositorio guarda y lee por libro', () async {
      final r = RepositorioPatrimonioEnMemoria();
      await r.guardarInversion(
        inversionCapturada(
          id: 'i1',
          libroId: libro,
          nombre: 'X',
          saldoCentavos: 1,
          fechaCaptura: hoy,
          rendimientoPuntosBase: 0,
        ),
      );
      expect(await r.inversiones(libro), hasLength(1));
      expect(await r.inversiones('otro'), isEmpty);
    });
  });

  group('bienes y previsión', () {
    test('sin fecha de captura no es vigente', () {
      const sin = Bien(
        id: 'b1',
        libroId: libro,
        tipo: TipoBien.auto,
        nombre: 'Auto de ejemplo',
        valorCentavos: 20000000,
      );
      final con = Bien(
        id: 'b2',
        libroId: libro,
        tipo: TipoBien.casa,
        nombre: 'Casa de ejemplo',
        valorCentavos: 100000000,
        fechaCaptura: hoy,
      );
      expect(sin.vigente, isFalse);
      expect(con.vigente, isTrue);
    });

    test('una previsión sin fecha de captura no es vigente', () {
      const sin = Prevision(
        id: 'p1',
        libroId: libro,
        tipo: TipoPrevision.seguro,
        nombre: 'Seguro de ejemplo',
        valorCentavos: 100,
      );
      final con = Prevision(
        id: 'p2',
        libroId: libro,
        tipo: TipoPrevision.pension,
        nombre: 'Pensión de ejemplo',
        valorCentavos: 100,
        fechaCaptura: hoy,
      );
      expect(sin.vigente, isFalse);
      expect(con.vigente, isTrue);
    });
  });

  group('repositorio de Supabase (migración 20261136)', () {
    late FuenteTablasEnMemoria fuente;
    late RepositorioPatrimonioSupabase repo;
    setUp(() {
      fuente = FuenteTablasEnMemoria();
      repo = RepositorioPatrimonioSupabase(fuente);
    });
    Map<String, Object?> llamada(String f) =>
        fuente.llamadas.singleWhere((l) => l.$1 == f).$2;

    test(
      'objetivo sin fecha llama fin_objetivo_guardar con fecha nula',
      () async {
        await repo.guardarObjetivo(
          const Objetivo(
            id: 'o1',
            libroId: libro,
            titularId: 'p1',
            nombre: 'Viaje',
            metaCentavos: 500000,
            bolsaId: 'b1',
          ),
        );
        expect(llamada('fin_objetivo_guardar'), {
          'p_id': 'o1',
          'p_libro': libro,
          'p_titular': 'p1',
          'p_nombre': 'Viaje',
          'p_monto_meta_centavos': 500000,
          'p_fecha_meta': null,
          'p_bolsa': 'b1',
        });
      },
    );

    test(
      'inversión con rendimiento cero llama fin_inversion_guardar',
      () async {
        await repo.guardarInversion(
          inversionCapturada(
            id: 'i1',
            libroId: libro,
            titularId: 'p1',
            nombre: 'Fondo',
            saldoCentavos: 1000,
            fechaCaptura: hoy,
            rendimientoPuntosBase: 0,
          ),
        );
        final p = llamada('fin_inversion_guardar');
        expect(p['p_rendimiento_pb'], 0);
        expect(p['p_origen'], 'capturado');
        expect(p['p_saldo_centavos'], 1000);
        expect(p['p_titular'], 'p1');
        expect(p['p_fecha_captura'], hoy.toString());
      },
    );

    test('bien y previsión llaman sus RPC', () async {
      await repo.guardarBien(
        Bien(
          id: 'b1',
          libroId: libro,
          titularId: 'p1',
          tipo: TipoBien.auto,
          nombre: 'Auto',
          valorCentavos: 9,
          fechaCaptura: hoy,
        ),
      );
      await repo.guardarPrevision(
        const Prevision(
          id: 'v1',
          libroId: libro,
          titularId: 'p1',
          tipo: TipoPrevision.seguro,
          nombre: 'Seguro',
          valorCentavos: 8,
        ),
      );
      expect(llamada('fin_bien_guardar')['p_tipo'], 'auto');
      expect(llamada('fin_prevision_guardar')['p_fecha_captura'], isNull);
    });

    test('sin titular no llama al servidor', () async {
      await expectLater(
        repo.guardarObjetivo(
          const Objetivo(
            id: 'o1',
            libroId: libro,
            nombre: 'X',
            metaCentavos: 1,
          ),
        ),
        throwsStateError,
      );
      expect(fuente.llamadas, isEmpty);
    });

    test(
      'lee las tablas reales, solo lo activo, y la vista de vigentes',
      () async {
        fuente.tabla('fin_objetivos').addAll([
          {
            'id': 'o1',
            'libro_id': libro,
            'nombre': 'A',
            'monto_meta_centavos': 100,
            'fecha_meta': null,
            'bolsa_id': null,
            'activo': true,
          },
          {
            'id': 'o2',
            'libro_id': libro,
            'nombre': 'Baja',
            'monto_meta_centavos': 100,
            'fecha_meta': '2027-01-05',
            'activo': false,
          },
        ]);
        fuente.tabla('fin_v_inversiones_vigentes').add({
          'id': 'i1',
          'libro_id': libro,
          'nombre': 'F',
          'saldo_centavos': 50,
          'rendimiento_pb': 0,
          'origen': 'capturado',
          'fecha_captura': '2026-11-09',
        });
        fuente.tabla('fin_bienes').add({
          'id': 'b1',
          'libro_id': libro,
          'nombre': 'Casa',
          'tipo': 'casa',
          'valor_centavos': 7,
          'fecha_captura': null,
          'activo': true,
        });
        fuente.tabla('fin_previsiones').add({
          'id': 'v1',
          'libro_id': libro,
          'nombre': 'Pensión',
          'tipo': 'pension',
          'valor_centavos': 7,
          'fecha_captura': '2026-11-01',
          'activa': true,
        });
        final os = await repo.objetivos(libro);
        expect(os.map((o) => o.id), ['o1']);
        expect(os.single.fechaMeta, isNull);
        expect(os.single.metaCentavos, 100);
        expect((await repo.inversiones(libro)).single.rendimientoPuntosBase, 0);
        expect((await repo.bienes(libro)).single.vigente, isFalse);
        expect((await repo.previsiones(libro)).single.vigente, isTrue);
      },
    );

    test('el avance llama fin_objetivo_avance', () async {
      fuente.funciones['fin_objetivo_avance'] = (_) => [
        {'estado': 'ok', 'semanas_estimadas': 20, 'a_tiempo': null},
      ];
      final a = await repo.avance('o1', hoy);
      expect(a!['semanas_estimadas'], 20);
      expect(llamada('fin_objetivo_avance'), {
        'p_objetivo': 'o1',
        'p_hoy': hoy.toString(),
      });
    });
  });

  group('reglas por cuenta (D19)', () {
    final libros = datosDeDemostracion(hoy: hoyDePrueba).libros;
    Libro de(String id) => libros.firstWhere((l) => l.id == id);

    PermisoPatrimonio de_(
      Rol rol,
      String personaId,
      String libroId, {
      bool maestra = false,
    }) {
      final p = permisoEnLibro(
        de(libroId),
        personaId,
        hoy: hoyDePrueba,
        esMaestra: maestra,
        rolConFinanzas: permisos.puede(rol, Modulo.finanzas, Accion.leer),
      );
      return permisoPatrimonio(p, rol);
    }

    final dueno = IdsDemostracion.dueno;
    final pareja = IdsDemostracion.pareja;

    test('la titular ve y edita lo suyo', () {
      final p = de_(Rol.dueno, dueno, IdsDemostracion.libroDueno);
      expect((p.ver, p.editar), (true, true));
      final q = de_(Rol.coadministrador, pareja, IdsDemostracion.libroPareja);
      expect((q.ver, q.editar), (true, true));
    });

    test('el dueño como albacea de Papá ve y edita lo de Papá', () {
      final p = de_(Rol.dueno, dueno, IdsDemostracion.libroPapa);
      expect((p.ver, p.editar), (true, true));
    });

    test('el suplente de Papá solo lee mientras hay albacea', () {
      final p = de_(Rol.coadministrador, pareja, IdsDemostracion.libroPapa);
      expect((p.ver, p.editar), (true, false));
    });

    test('la pareja ve lo de la casa', () {
      final p = de_(Rol.coadministrador, pareja, IdsDemostracion.libroCasa);
      expect(p.ver, isTrue);
    });

    test('nadie ve lo personal de otro, ni como cuenta maestra', () {
      expect(
        de_(Rol.coadministrador, pareja, IdsDemostracion.libroDueno).ver,
        isFalse,
      );
      expect(
        de_(
          Rol.coadministrador,
          IdsDemostracion.pareja,
          IdsDemostracion.libroDueno,
          maestra: true,
        ).ver,
        isFalse,
      );
    });

    test('Casa, familiar y cuidadora no ven nada', () {
      for (final rol in [Rol.casa, Rol.familiar, Rol.cuidador]) {
        for (final id in [
          IdsDemostracion.libroCasa,
          IdsDemostracion.libroDueno,
          IdsDemostracion.libroPapa,
        ]) {
          // Aun siendo miembro del libro, el rol no tiene Finanzas.
          final p = de_(rol, dueno, id);
          expect((p.ver, p.editar), (false, false), reason: '$rol $id');
        }
      }
    });

    test('solo lectura total no edita', () {
      final p = permisoEnLibro(
        de(IdsDemostracion.libroDueno),
        dueno,
        hoy: hoyDePrueba,
      );
      expect(
        permisoPatrimonio(p, Rol.dueno, soloLectura: true).editar,
        isFalse,
      );
    });
  });
}
