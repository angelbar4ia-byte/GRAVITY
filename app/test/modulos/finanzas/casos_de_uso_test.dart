// Casos de uso de Finanzas (Fase 1): ids estables para reintentar sin chocar
// con los únicos del servidor, anulación única por movimiento, importación de
// la hoja Categorías con el archivo semilla real, cierre de semana con
// versión = reaperturas + 1 y permisos por libro (D19).
import 'dart:io';

import 'package:finanzas_dominio/finanzas_dominio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/casos_uso/servicio_finanzas.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio.dart';
import 'package:gravity/modulos/finanzas/importacion/lector_xlsx.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart'
    show hogarDeEjemplo;

import 'ayuda_finanzas.dart';

const _uuidV5 =
    r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';

String _rutaSemilla() {
  for (final r in [
    '../data/DATOS_SEMILLA_PRESUPUESTO.xlsx',
    'data/DATOS_SEMILLA_PRESUPUESTO.xlsx',
  ]) {
    if (File(r).existsSync()) return r;
  }
  throw StateError('No encontré data/DATOS_SEMILLA_PRESUPUESTO.xlsx');
}

void main() {
  const libroDueno = IdsDemostracion.libroDueno;
  const libroCasa = IdsDemostracion.libroCasa;
  const libroPapa = IdsDemostracion.libroPapa;
  final dueno = sesionDe(Rol.dueno);
  final pareja = sesionDe(Rol.coadministrador);
  final semana = Semana.de(hoyDePrueba);

  group('Ids estables (UUID v5)', () {
    test(
      'la misma clave da siempre el mismo id y distintas claves, distintos',
      () {
        expect(idEstable('a'), idEstable('a'));
        expect(idEstable('a'), isNot(idEstable('b')));
        expect(idEstable('a'), matches(RegExp(_uuidV5)));
      },
    );

    test('la anulación sale del id del original', () {
      expect(
        ServicioFinanzas.idAnulacionDe('mov-1'),
        idEstable(ClavesId.anulacion('mov-1')),
      );
      expect(ServicioFinanzas.idAnulacionDe('mov-1'), matches(RegExp(_uuidV5)));
      expect(
        ServicioFinanzas.idAnulacionDe('mov-1'),
        isNot(ServicioFinanzas.idAnulacionDe('mov-2')),
      );
    });
  });

  group('Anular y deshacer', () {
    test('el contraasiento lleva el id derivado del original, en cualquier '
        'dispositivo', () async {
      final repoA = repositorioDe(dueno);
      final repoB = repositorioDe(dueno);
      final original = repoA.datos.movimientos.firstWhere(
        (m) =>
            m.tipo == TipoMovimiento.gasto &&
            repoA.datos.cuenta(m.cuentaOrigenId)?.libroId == libroDueno,
      );
      final a = await servicioDe(
        repoA,
        dueno,
      ).anular(original.id, motivo: 'Error');
      final b = await servicioDe(
        repoB,
        dueno,
      ).anular(original.id, motivo: 'Error');
      expect(a.id, ServicioFinanzas.idAnulacionDe(original.id));
      expect(b.id, a.id, reason: 'otro dispositivo, mismo id');
      expect(a.fecha, original.fecha, reason: 'misma fecha económica (P14)');
    });

    test('anular dos veces no duplica (índice único en anula_a)', () async {
      final repo = repositorioDe(dueno);
      final servicio = servicioDe(repo, dueno);
      final r = await servicio.registrarGasto(
        libroId: libroDueno,
        cuentaOrigenId: repo.cuentaDe(libroDueno, 'Mi efectivo').id,
        lineas: const [LineaGasto(monto: 8500)],
      );
      await servicio.deshacer(r);
      await expectLater(servicio.deshacer(r), throwsA(isA<ErrorFinanzas>()));
      final anulaciones = repo.datos.movimientos.where(
        (m) => m.anulaA == r.movimientos.single.id,
      );
      expect(anulaciones, hasLength(1));
      expect(anulaciones.single.motivo, motivoDeshacer);
    });

    test(
      'reenviar el mismo contraasiento no hace nada (mismo id y contenido)',
      () async {
        final repo = repositorioDe(dueno);
        final original = repo.datos.movimientos.firstWhere(
          (m) =>
              m.tipo == TipoMovimiento.gasto &&
              repo.datos.cuenta(m.cuentaOrigenId)?.libroId == libroDueno,
        );
        final contra = await servicioDe(
          repo,
          dueno,
        ).anular(original.id, motivo: 'Dup');
        final antes = repo.datos.movimientos.length;
        await repo.agregarMovimientos([contra]);
        expect(repo.datos.movimientos, hasLength(antes));
      },
    );

    test('anular exige motivo', () async {
      final repo = repositorioDe(dueno);
      final id = repo.datos.movimientos.first.id;
      await expectLater(
        servicioDe(repo, dueno).anular(id, motivo: '  '),
        throwsA(isA<ErrorFinanzas>()),
      );
    });
  });

  group('Permisos por libro (D19)', () {
    test('la pareja no registra en el libro del dueño ni lo ve', () async {
      final repo = repositorioDe(pareja);
      expect(repo.datos.libro(libroDueno), isNull);
      await expectLater(
        servicioDe(repo, pareja).registrarGasto(
          libroId: libroDueno,
          cuentaOrigenId: 'x',
          lineas: const [LineaGasto(monto: 100)],
        ),
        throwsA(isA<ErrorFinanzas>()),
      );
    });

    test('la cuenta maestra lee todo y no registra en lo ajeno', () async {
      final maestra = sesionDe(Rol.dueno, maestra: true);
      final repo = repositorioDe(maestra);
      expect(repo.datos.libros, hasLength(4), reason: 've todos');
      final servicio = servicioDe(repo, maestra);
      expect(servicio.permiso(libroDueno).escribir, isFalse);
      expect(servicio.permiso(libroDueno).leer, isTrue);
      await expectLater(
        servicio.registrarGasto(
          libroId: libroDueno,
          cuentaOrigenId: repo.cuentaDe(libroDueno, 'Mi efectivo').id,
          lineas: const [LineaGasto(monto: 100)],
        ),
        throwsA(isA<ErrorFinanzas>()),
      );
    });

    test('el suplente escribe solo si no hay albacea vigente (D17)', () {
      final repo = repositorioDe(pareja);
      final servicio = servicioDe(repo, pareja);
      final papa = repo.datos.libro(libroPapa)!;
      expect(
        papa.papelDe(pareja.persona.id, hoyDePrueba),
        PapelLibro.albaceaSuplente,
      );
      expect(servicio.permiso(libroPapa).leer, isTrue);
      expect(servicio.permiso(libroPapa).escribir, isFalse);
    });

    test('en el libro de papá todo va en su nombre y con motivo', () async {
      final repo = repositorioDe(dueno);
      final servicio = servicioDe(repo, dueno);
      final cuenta = repo.cuentaDe(libroPapa, 'Cuenta de la pensión').id;
      await expectLater(
        servicio.registrarGasto(
          libroId: libroPapa,
          cuentaOrigenId: cuenta,
          lineas: const [LineaGasto(monto: 5000)],
        ),
        throwsA(isA<ErrorFinanzas>()),
        reason: 'sin motivo',
      );
      final r = await servicio.registrarGasto(
        libroId: libroPapa,
        cuentaOrigenId: cuenta,
        lineas: const [LineaGasto(monto: 5000)],
        motivo: 'Medicinas',
      );
      final m = r.movimientos.single;
      expect(m.enNombreDe, IdsDemostracion.papa);
      expect(m.realizadoPor, IdsDemostracion.papa);
      expect(m.registradoPor, dueno.persona.id);
    });

    test('solo una transferencia o un pago de deuda cruzan de libro', () async {
      final repo = repositorioDe(dueno);
      final servicio = servicioDe(repo, dueno);
      final banco = repo.cuentaDe(libroDueno, 'Mi banco').id;
      final bancoCasa = repo.cuentaDe(libroCasa, 'Banco de la casa').id;
      final aportacion = await servicio.registrarMovimiento(
        tipo: TipoMovimiento.transferencia,
        cuentaOrigenId: banco,
        cuentaDestinoId: bancoCasa,
        monto: 20000,
        nota: 'Aportación',
      );
      expect(aportacion.movimientos, hasLength(1));
      // Sus dos libros cuadran: cambia el patrimonio sin pasar por el resultado.
      final deDueno = repo.datos.vista(libroDueno).balance();
      final deCasa = repo.datos.vista(libroCasa).balance();
      expect(deDueno.aportacionesEntregadas, 20000);
      expect(
        deCasa.aportacionesRecibidas,
        20000 + 50000,
        reason: 'la de la pareja (ejemplo) y esta',
      );
      expect(deDueno.cuadra, isTrue);
      expect(deCasa.cuadra, isTrue);
      await expectLater(
        servicio.registrarMovimiento(
          tipo: TipoMovimiento.ingreso,
          cuentaOrigenId: repo.cuentaDe(libroCasa, 'Extras').id,
          cuentaDestinoId: banco,
          monto: 100,
        ),
        throwsA(isA<ErrorFinanzas>()),
      );
    });
  });

  group('Importar la hoja Categorías (criterio 29)', () {
    late LecturaPlantilla lectura;

    setUpAll(() async {
      lectura = await leerPlantillaDeRuta(_rutaSemilla());
    });

    test(
      'crea el árbol con su naturaleza y la cuenta de gasto de cada rubro',
      () async {
        final repo = repositorioVacio();
        final plan = await servicioDe(repo, dueno).importarCategorias(
          lectura,
          archivo: 'DATOS_SEMILLA_PRESUPUESTO.xlsx',
        );
        expect(plan.nuevas, isNotEmpty);
        expect(repo.datos.categorias, hasLength(plan.nuevas.length));
        final principales = repo.datos.categorias.where((c) => c.nivel == 1);
        expect(principales, isNotEmpty);
        for (final c in principales) {
          final cuenta = repo.datos.cuenta(c.cuentaGastoId!);
          expect(cuenta, isNotNull, reason: c.nombre);
          expect(
            cuenta!.tipo,
            anyOf(TipoCuenta.deGasto, TipoCuenta.gastoFinanciero),
          );
          expect(cuenta.libroId, isNull, reason: 'las de gasto son del hogar');
        }
        expect(repo.datos.categorias.map((c) => c.nivel).toSet(), contains(2));
        expect(repo.datos.importaciones, hasLength(1));
        expect(repo.datos.importaciones.single.filasCreadas, plan.filasCreadas);
      },
    );

    test('reimportar no duplica nada', () async {
      final repo = repositorioVacio();
      final servicio = servicioDe(repo, dueno);
      await servicio.importarCategorias(lectura, archivo: 'a.xlsx');
      final categorias = repo.datos.categorias.length;
      final cuentas = repo.datos.cuentas.length;
      final otra = await servicio.importarCategorias(
        lectura,
        archivo: 'a.xlsx',
      );
      expect(otra.nuevas, isEmpty);
      expect(otra.cuentasNuevas, isEmpty);
      expect(repo.datos.categorias, hasLength(categorias));
      expect(repo.datos.cuentas, hasLength(cuentas));
      expect(
        repo.datos.categorias.map((c) => c.id).toSet(),
        hasLength(categorias),
        reason: 'sin ids repetidos',
      );
    });

    test('los ids salen de la ruta: otro dispositivo importa con los mismos '
        'ids y el reintento no choca con los únicos', () async {
      final a = repositorioVacio();
      final b = repositorioVacio();
      await servicioDe(a, dueno).importarCategorias(lectura, archivo: 'a.xlsx');
      await servicioDe(b, dueno).importarCategorias(lectura, archivo: 'a.xlsx');
      expect(
        a.datos.categorias.map((c) => c.id).toList()..sort(),
        b.datos.categorias.map((c) => c.id).toList()..sort(),
      );
      expect(
        a.datos.cuentas.map((c) => c.id).toList()..sort(),
        b.datos.cuentas.map((c) => c.id).toList()..sort(),
      );
      expect(a.datos.categorias.first.id, matches(RegExp(_uuidV5)));
    });

    test('con otro hogar los ids son otros (no se mezclan)', () async {
      final repo = repositorioVacio();
      final plan = await ServicioFinanzas(
        repositorio: repo,
        personaId: dueno.persona.id,
        hogarId: 'otro-hogar',
      ).importarCategorias(lectura, archivo: 'a.xlsx');
      final deAqui = servicioDe(
        repositorioVacio(),
        dueno,
      ).previsualizarImportacion(lectura);
      expect(plan.nuevas.first.id, isNot(deAqui.nuevas.first.id));
    });
  });

  group('Activar y cerrar la semana', () {
    test('activar usa ids estables: la semana y sus partidas salen del libro '
        'y del lunes', () async {
      final a = repositorioDe(dueno);
      final b = repositorioDe(dueno);
      final fa = await servicioDe(a, dueno).activarSemana(libroDueno, semana);
      final fb = await servicioDe(b, dueno).activarSemana(libroDueno, semana);
      expect(fa.id, idEstable(ClavesId.semana(libroDueno, '${semana.inicio}')));
      expect(fb.id, fa.id);
      expect(fa.partidas.map((p) => p.id), fb.partidas.map((p) => p.id));
      expect(
        fa.partidas.map((p) => p.id).toSet(),
        hasLength(fa.partidas.length),
      );
      await expectLater(
        servicioDe(a, dueno).activarSemana(libroDueno, semana),
        throwsA(isA<ErrorFinanzas>()),
        reason: 'ya está activada',
      );
    });

    test('cerrar guarda la versión reaperturas + 1; reabrir y cerrar crea la '
        'versión 2 con otro id', () async {
      final repo = repositorioDe(dueno);
      final servicio = servicioDe(repo, dueno);
      final foto = await servicio.activarSemana(libroDueno, semana);
      final c1 = await servicio.cerrarSemana(libroDueno, semana);
      expect(c1.version, 1);
      expect(c1.id, idEstable(ClavesId.cierre(foto.id, 1)));
      expect(
        repo.datos.semanaGuardada(libroDueno, semana)!.estado,
        EstadoSemana.cerrada,
      );
      await servicio.reabrirSemana(libroDueno, semana);
      final reabierta = repo.datos.semanaGuardada(libroDueno, semana)!;
      expect(reabierta.estado, EstadoSemana.activa);
      expect(reabierta.reaperturas, 1);
      final c2 = await servicio.cerrarSemana(libroDueno, semana);
      expect(c2.version, 2);
      expect(c2.id, isNot(c1.id));
      expect(c2.id, idEstable(ClavesId.cierre(foto.id, 2)));
    });

    test('aplicar el remanente dos veces no duplica los movimientos', () async {
      final repo = repositorioDe(dueno);
      final servicio = servicioDe(repo, dueno);
      final tarjeta = repo.datos
          .deudasDe(libroCasa)
          .firstWhere((d) => d.nombre == 'Tarjeta de crédito');
      final destino = DestinoRemanente([
        AbonoExtra(tarjeta.plan(saldo: 600000), 15000),
      ], 0);
      final banco = repo.cuentaDe(libroCasa, 'Banco de la casa').id;
      final antes = repo.datos.movimientos.length;
      final primera = await servicio.aplicarRemanente(
        libroId: libroCasa,
        destino: destino,
        cuentaOrigenId: banco,
        cierreId: 'cierre-1',
      );
      final segunda = await servicio.aplicarRemanente(
        libroId: libroCasa,
        destino: destino,
        cuentaOrigenId: banco,
        cierreId: 'cierre-1',
      );
      expect(primera.single.id, segunda.single.id);
      expect(repo.datos.movimientos, hasLength(antes + 1));
      expect(primera.single.tipo, TipoMovimiento.pagoDeuda);
    });

    test('la cuenta maestra no activa ni cierra semanas ajenas', () async {
      final maestra = sesionDe(Rol.dueno, maestra: true);
      final repo = repositorioDe(maestra);
      await expectLater(
        servicioDe(repo, maestra).activarSemana(libroDueno, semana),
        throwsA(isA<ErrorFinanzas>()),
      );
    });
  });

  group('Cuentas e ingresos con ids estables', () {
    test('la cuenta Extras se crea una vez aunque se reintente', () async {
      final repo = repositorioDe(dueno);
      final servicio = servicioDe(repo, dueno);
      final banco = repo.cuentaDe(libroDueno, 'Mi banco').id;
      // En el ejemplo el libro del dueño ya tiene "Extras": se reutiliza.
      final antes = repo.datos.cuentasDe(libroDueno).length;
      await servicio.registrarIngresoExtra(
        libroId: libroDueno,
        monto: 10000,
        cuentaDestinoId: banco,
      );
      expect(repo.datos.cuentasDe(libroDueno), hasLength(antes));
    });

    test(
      'un ingreso nuevo con el nombre de una cuenta existente avisa',
      () async {
        final repo = repositorioDe(dueno);
        await expectLater(
          servicioDe(repo, dueno).crearIngreso(
            libroId: libroDueno,
            nombre: 'Mi banco',
            montoNeto: 100000,
            calendario: const CalendarioConfig.quincenal(),
            cuentaDestinoId: repo.cuentaDe(libroDueno, 'Mi banco').id,
          ),
          throwsA(isA<ErrorFinanzas>()),
        );
      },
    );

    test(
      'la categoría principal nueva usa una cuenta de gasto con id estable',
      () async {
        final repo = repositorioDe(dueno);
        final servicio = servicioDe(repo, dueno);
        final c = await servicio.crearCategoria(nombre: 'Mascotas');
        final cuenta = repo.datos.cuenta(c.cuentaGastoId!)!;
        expect(
          cuenta.id,
          idEstable(ClavesId.cuentaDeGasto(hogarDeEjemplo, 'Mascotas')),
        );
        expect(cuenta.libroId, isNull);
        expect(cuenta.tipo, TipoCuenta.deGasto);
      },
    );

    test(
      'un libro compartido y el de papá se crean con id del nombre',
      () async {
        final repo = repositorioVacio();
        final servicio = servicioDe(repo, dueno);
        final id = await servicio.crearLibroCompartido('Vacaciones', [
          IdsDemostracion.pareja,
        ]);
        expect(
          id,
          idEstable(ClavesId.libroCompartido(hogarDeEjemplo, 'Vacaciones')),
        );
        await servicio.crearLibroCompartido('Vacaciones', [
          IdsDemostracion.pareja,
        ]);
        expect(repo.datos.libros.where((l) => l.id == id), hasLength(1));
        final papa = await servicio.crearLibroRepresentado(
          'Papá (ejemplo)',
          suplenteId: IdsDemostracion.pareja,
        );
        await servicio.crearLibroRepresentado('Papá (ejemplo)');
        final libro = repo.datos.libro(papa)!;
        expect(libro.tipo, TipoLibro.representado);
        expect(
          libro.papelDe(dueno.persona.id, hoyDePrueba),
          PapelLibro.albacea,
        );
        expect(
          libro.papelDe(IdsDemostracion.pareja, hoyDePrueba),
          PapelLibro.albaceaSuplente,
        );
        expect(repo.datos.libros.where((l) => l.id == papa), hasLength(1));
        await expectLater(
          servicio.crearLibroCompartido('Solo yo', const []),
          throwsA(isA<ErrorFinanzas>()),
        );
      },
    );
  });
}
