import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/diseno/proveedores.dart' show RelojFijo, relojProvider;
import 'package:gravity/modulos/cuidados/casos_uso/horario_turnos.dart';
import 'package:gravity/modulos/cuidados/casos_uso/permisos_cuidados.dart';
import 'package:gravity/modulos/cuidados/casos_uso/servicio_cuidados.dart';
import 'package:gravity/modulos/cuidados/datos/modelos.dart';
import 'package:gravity/modulos/cuidados/datos/repositorio.dart';
import 'package:gravity/modulos/cuidados/datos/repositorio_supabase.dart';
import 'package:gravity/modulos/cuidados/estado/proveedores.dart';
import 'package:gravity/modulos/cuidados/pantallas/bitacora.dart';
import 'package:gravity/modulos/cuidados/pantallas/comidas.dart';
import 'package:gravity/modulos/cuidados/pantallas/medicamentos.dart';
import 'package:gravity/modulos/cuidados/pantallas/mi_turno.dart';
import 'package:gravity/modulos/cuidados/pantallas/resumen_mensual.dart';
import 'package:gravity/modulos/finanzas/datos/fuente_tablas.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

// Miércoles 4/nov/2026, 10:00: la cuidadora está de turno (7:30 a 18:30).
final _miercoles10 = DateTime(2026, 11, 4, 10);
final _martes16 = DateTime(2026, 11, 3, 16);
final _sabado16 = DateTime(2026, 11, 7, 16);
final _domingo12 = DateTime(2026, 11, 8, 12);
final _lunes = DateTime(2026, 11, 2);

const _cuidadora = 'persona-cuidadora';
const _hermana = 'persona-hermana';
const _dueno = 'persona-dueno';
const _pareja = 'persona-pareja';

DatosCuidadosMemoria _datos([DateTime? ahora]) =>
    datosDeEjemploCuidados(ahora ?? _miercoles10);

RepositorioCuidadosEnMemoria _repo(
  DatosCuidadosMemoria d,
  String id,
  Rol rol, {
  PerfilCuidados perfil = const PerfilCuidados(),
}) => RepositorioCuidadosEnMemoria(
  datos: d,
  personaId: id,
  rol: rol,
  perfilActual: perfil,
);

const _perfilHermana = PerfilCuidados(
  esFamiliar: true,
  resumenAutorizado: true,
);

ServicioCuidados _srv(
  DatosCuidadosMemoria d,
  String id,
  Rol rol, {
  PerfilCuidados perfil = const PerfilCuidados(),
  DateTime? ahora,
  bool maestra = false,
}) => ServicioCuidados(
  _repo(d, id, rol, perfil: perfil),
  permisos: PermisosCuidados(rol: rol, perfil: perfil, esMaestra: maestra),
  personaId: id,
  nombre: id,
  ahora: () => ahora ?? _miercoles10,
);

Widget _app(
  Widget pantalla,
  DatosCuidadosMemoria d,
  String id,
  Rol rol, {
  PerfilCuidados perfil = const PerfilCuidados(),
}) => ProviderScope(
  overrides: [
    relojProvider.overrideWithValue(RelojFijo(_miercoles10)),
    almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
    servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
    sesionEfectivaProvider.overrideWithValue(
      Sesion(
        persona: Persona(id: id, nombre: id),
        rol: rol,
      ),
    ),
    repositorioCuidadosProvider.overrideWithValue(
      _repo(d, id, rol, perfil: perfil),
    ),
  ],
  child: MaterialApp(home: pantalla),
);

Future<void> _alto(WidgetTester t) async {
  await t.binding.setSurfaceSize(const Size(400, 3000));
  addTearDown(() => t.binding.setSurfaceSize(null));
}

void main() {
  group('Turnos y recordatorios (criterio 1)', () {
    final turnos = turnosDeLaSemana(_lunes, personasDemo);

    test('el miércoles a media mañana está de turno la cuidadora', () {
      expect(deTurnoAhora(turnos, _miercoles10), {_cuidadora});
    });

    test('el martes por la tarde le toca a la hermana, no a la cuidadora', () {
      expect(deTurnoAhora(turnos, _martes16), {_hermana});
      expect(recibeRecordatorio(_cuidadora, turnos, _martes16), isFalse);
    });

    test('sábado por la tarde y domingo: el dueño; las visitas no cuentan', () {
      expect(deTurnoAhora(turnos, _sabado16), {_dueno});
      expect(deTurnoAhora(turnos, _domingo12), {_dueno});
      expect(recibeRecordatorio(_hermana, turnos, _domingo12), isFalse);
    });

    test('fuera de turno no llega nada a la cuidadora (de noche)', () {
      expect(
        recibeRecordatorio(_cuidadora, turnos, DateTime(2026, 11, 4, 20)),
        isFalse,
      );
      expect(
        recibeRecordatorio(_cuidadora, turnos, DateTime(2026, 11, 4, 18, 30)),
        isFalse,
      );
      expect(
        recibeRecordatorio(_cuidadora, turnos, DateTime(2026, 11, 4, 18, 29)),
        isTrue,
      );
    });

    test('la hermana se va a las 7:00 del miércoles', () {
      expect(
        recibeRecordatorio(_hermana, turnos, DateTime(2026, 11, 4, 6, 59)),
        isTrue,
      );
      expect(
        recibeRecordatorio(_hermana, turnos, DateTime(2026, 11, 4, 7)),
        isFalse,
      );
    });

    test('Mi turno: la cuidadora ve su turno de hoy', () async {
      final s = _srv(_datos(), _cuidadora, Rol.cuidador);
      final mio = await s.miTurnoHoy();
      expect(mio.single.horario, '07:30 a 18:30');
      expect(await s.deTurno(), {_cuidadora});
    });
  });

  group('Permisos por rol (matriz de la sección 5)', () {
    test('dueño: todo; cuidadora: su parte; hermana: lectura y resumen', () {
      const dueno = PermisosCuidados(rol: Rol.dueno);
      expect(
        dueno.administra && dueno.confirmaGasto && dueno.marcaToma,
        isTrue,
      );
      expect(dueno.resumenDisponible && dueno.veBitacora, isTrue);

      const cuid = PermisosCuidados(rol: Rol.cuidador);
      expect(cuid.marcaToma && cuid.registraComida, isTrue);
      expect(cuid.escribeBitacora && cuid.registraGasto, isTrue);
      expect(cuid.veResumen, isFalse);
      expect(cuid.administra || cuid.confirmaGasto, isFalse);

      const her = PermisosCuidados(rol: Rol.cuidador, perfil: _perfilHermana);
      expect(her.veMedicamentos && her.veComidas, isTrue);
      expect(her.marcaToma || her.registraComida, isFalse);
      expect(her.escribeBitacora && her.registraGasto, isTrue);
      expect(her.resumenDisponible, isTrue);
    });

    test('pareja: sin consentimiento no entra; con él, solo lectura y sin bitácora', () {
      const sin = PermisosCuidados(rol: Rol.coadministrador);
      expect(sin.entra, isFalse);
      const con = PermisosCuidados(
        rol: Rol.coadministrador,
        perfil: PerfilCuidados(consentimiento: true),
      );
      expect(con.veTurno && con.veMedicamentos && con.veComidas, isTrue);
      expect(con.marcaToma || con.registraComida, isFalse);
      expect(con.veBitacora || con.veResumen, isFalse);
    });

    test('familiar y casa no entran; la cuenta maestra solo lee', () {
      expect(const PermisosCuidados(rol: Rol.familiar).entra, isFalse);
      expect(const PermisosCuidados(rol: Rol.casa).entra, isFalse);
      const maestra = PermisosCuidados(rol: Rol.cuidador, esMaestra: true);
      expect(maestra.marcaToma || maestra.escribeBitacora, isFalse);
    });
  });

  group('Marcar toma', () {
    test(
      'la cuidadora marca "dado" y queda registrado con su nombre',
      () async {
        final d = _datos();
        final s = _srv(d, _cuidadora, Rol.cuidador);
        final antes = await s.dosisDelDia();
        expect(antes.map((x) => horaTexto(x.hora)), [
          '08:00',
          '14:00',
          '20:00',
        ]);
        expect(antes.every((x) => x.estado == EstadoToma.pendiente), isTrue);
        await s.marcarToma(antes.first, dado: true);
        await s.marcarToma(antes[1], dado: false);
        final despues = await s.dosisDelDia();
        expect(despues[0].estado, EstadoToma.dado);
        expect(despues[0].toma!.registradaPorNombre, _cuidadora);
        expect(despues[1].estado, EstadoToma.noDado);
        expect(despues[2].estado, EstadoToma.pendiente);
        // Marcar dos veces no duplica: mismo id.
        await s.marcarToma(antes.first, dado: true);
        expect(d.tomas.length, 2);
      },
    );

    test('la hermana y la pareja no marcan (servicio y servidor)', () async {
      final d = _datos();
      final her = _srv(d, _hermana, Rol.cuidador, perfil: _perfilHermana);
      final dosis = (await her.dosisDelDia()).first;
      expect(
        () => her.marcarToma(dosis, dado: true),
        throwsA(isA<ErrorCuidados>()),
      );
      // Aunque la interfaz fallara, la "base" también lo rechaza.
      final toma = Toma(
        id: 'x',
        medicamentoId: 'med-1',
        programada: dosis.hora,
        estado: EstadoToma.dado,
        registradaPor: _hermana,
        registradaPorNombre: 'h',
        registradaEn: _miercoles10,
      );
      expect(
        () => _repo(
          d,
          _hermana,
          Rol.cuidador,
          perfil: _perfilHermana,
        ).registrarToma(toma),
        throwsA(isA<ErrorCuidados>()),
      );
    });

    test('la pareja sin consentimiento no ve medicamentos', () async {
      final s = _srv(_datos(), _pareja, Rol.coadministrador);
      expect(await s.dosisDelDia(), isEmpty);
    });
  });

  group('Comidas de Papá', () {
    test(
      'la cuidadora registra comió / comió poco / rechazó por tiempo',
      () async {
        final s = _srv(_datos(), _cuidadora, Rol.cuidador);
        await s.registrarComida(
          TiempoComidaPapa.desayuno,
          ResultadoComida.comio,
        );
        await s.registrarComida(
          TiempoComidaPapa.comida,
          ResultadoComida.rechazo,
        );
        await s.registrarComida(
          TiempoComidaPapa.comida,
          ResultadoComida.comioPoco,
        );
        final hoy = await s.comidasDeHoy();
        expect(
          hoy[TiempoComidaPapa.desayuno]!.resultado,
          ResultadoComida.comio,
        );
        expect(
          hoy[TiempoComidaPapa.comida]!.resultado,
          ResultadoComida.comioPoco,
        );
        expect(hoy.containsKey(TiempoComidaPapa.cena), isFalse);
      },
    );

    test('la hermana solo lee', () async {
      final d = _datos();
      final her = _srv(d, _hermana, Rol.cuidador, perfil: _perfilHermana);
      expect(
        () => her.registrarComida(TiempoComidaPapa.cena, ResultadoComida.comio),
        throwsA(isA<ErrorCuidados>()),
      );
      await _srv(
        d,
        _cuidadora,
        Rol.cuidador,
      ).registrarComida(TiempoComidaPapa.cena, ResultadoComida.comio);
      expect((await her.comidasDeHoy()).length, 1);
    });
  });

  group('Bitácora (criterio 2)', () {
    test(
      'cada cuidadora ve solo lo suyo; el dueño ve todo; la pareja nada',
      () async {
        final d = _datos();
        final c = _srv(d, _cuidadora, Rol.cuidador);
        final h = _srv(d, _hermana, Rol.cuidador, perfil: _perfilHermana);
        final o = _srv(d, _dueno, Rol.dueno);
        await c.agregarNota('Papá durmió bien');
        await h.agregarNota('Visita por la tarde');
        expect((await c.bitacora()).map((e) => e.texto), ['Papá durmió bien']);
        expect((await h.bitacora()).map((e) => e.texto), [
          'Visita por la tarde',
        ]);
        expect((await o.bitacora()).length, 2);
        final p = _srv(
          d,
          _pareja,
          Rol.coadministrador,
          perfil: const PerfilCuidados(consentimiento: true),
        );
        expect(await p.bitacora(), isEmpty);
      },
    );

    test('una nota vacía no se guarda', () async {
      final s = _srv(_datos(), _cuidadora, Rol.cuidador);
      expect(() => s.agregarNota('  '), throwsA(isA<ErrorCuidados>()));
    });
  });

  group('Gastos de cuidado', () {
    test(
      'el gasto de la cuidadora queda pendiente y solo el dueño confirma',
      () async {
        final d = _datos();
        final c = _srv(d, _cuidadora, Rol.cuidador);
        final o = _srv(d, _dueno, Rol.dueno);
        await c.registrarGasto(concepto: 'Pañales', centavos: 18550);
        final g = (await c.gastos()).single;
        expect(g.estado, EstadoGasto.pendiente);
        expect(g.centavos, 18550);
        expect(
          () => c.resolverGasto(g.id, confirmar: true),
          throwsA(isA<ErrorCuidados>()),
        );
        expect((await o.gastos()).single.estado, EstadoGasto.pendiente);
        await o.resolverGasto(g.id, confirmar: true);
        expect((await c.gastos()).single.estado, EstadoGasto.confirmado);
      },
    );

    test('cada quien ve solo los suyos; monto inválido se rechaza', () async {
      final d = _datos();
      final c = _srv(d, _cuidadora, Rol.cuidador);
      final h = _srv(d, _hermana, Rol.cuidador, perfil: _perfilHermana);
      await c.registrarGasto(concepto: 'Aseo', centavos: 5000);
      expect(await h.gastos(), isEmpty);
      expect(
        () => h.registrarGasto(concepto: 'x', centavos: 0),
        throwsA(isA<ErrorCuidados>()),
      );
      expect(
        () => h.registrarGasto(concepto: ' ', centavos: 100),
        throwsA(isA<ErrorCuidados>()),
      );
    });

    test('los montos se leen en pesos', () {
      expect(centavosDeTexto('150.50'), 15050);
      expect(centavosDeTexto(r'$1,200'), 120000);
      expect(centavosDeTexto('3.5'), 350);
      expect(centavosDeTexto('abc'), isNull);
    });
  });

  group('Resumen mensual (criterio 3)', () {
    final mes = DateTime(2026, 11);

    test(
      'la hermana autorizada ve el resumen sin la pareja ni el dueño',
      () async {
        final r = await _srv(
          _datos(),
          _hermana,
          Rol.cuidador,
          perfil: _perfilHermana,
        ).resumen(mes);
        expect(r, isNotNull);
        expect(r!.lineas.map((l) => l.titular).toSet(), {
          Titular.papa,
          Titular.casa,
        });
        expect(r.totalCentavos, 1200000 + 180000 + 350000);
      },
    );

    test('sin autorización del albacea no hay resumen', () async {
      const sinAut = PerfilCuidados(esFamiliar: true);
      expect(
        await _srv(
          _datos(),
          _hermana,
          Rol.cuidador,
          perfil: sinAut,
        ).resumen(mes),
        isNull,
      );
    });

    test(
      'la cuidadora y la pareja no lo ven; el dueño lo ve completo',
      () async {
        final d = _datos();
        expect(await _srv(d, _cuidadora, Rol.cuidador).resumen(mes), isNull);
        expect(
          await _srv(
            d,
            _pareja,
            Rol.coadministrador,
            perfil: const PerfilCuidados(consentimiento: true),
          ).resumen(mes),
          isNull,
        );
        final o = await _srv(d, _dueno, Rol.dueno).resumen(mes);
        expect(o!.lineas.length, 5);
      },
    );

    test(
      'aunque el servidor devolviera de más, la app lo quita a la hermana',
      () async {
        // Un repositorio que "olvida" filtrar: la app vuelve a filtrar.
        final d = _datos();
        final sucio = _RepoSinFiltro(_repo(d, _dueno, Rol.dueno));
        final s = ServicioCuidados(
          sucio,
          permisos: const PermisosCuidados(
            rol: Rol.cuidador,
            perfil: _perfilHermana,
          ),
          personaId: _hermana,
          nombre: 'h',
          ahora: () => _miercoles10,
        );
        final r = await s.resumen(mes);
        expect(
          r!.lineas.any(
            (l) => l.titular == Titular.pareja || l.titular == Titular.dueno,
          ),
          isFalse,
        );
      },
    );
  });

  group('Cambio urgente', () {
    test(
      'el dueño lo crea, la cuidadora lo atiende y el dueño lo ve',
      () async {
        final d = _datos();
        final o = _srv(d, _dueno, Rol.dueno);
        final c = _srv(d, _cuidadora, Rol.cuidador);
        await o.crearCambioUrgente(
          accion: AccionCambio.suspender,
          nota: 'Por indicación médica',
          medicamentoId: 'med-1',
          medicamentoNombre: 'Medicamento A',
        );
        expect((await o.cambiosUrgentes()).single.atendido, isFalse);
        expect(
          () => c.crearCambioUrgente(
            accion: AccionCambio.agregar,
            nota: '',
            medicamentoNombre: 'x',
          ),
          throwsA(isA<ErrorCuidados>()),
        );
        final id = (await c.cambiosUrgentes()).single.id;
        await c.atenderCambio(id);
        final visto = (await o.cambiosUrgentes()).single;
        expect(visto.atendido, isTrue);
        expect(visto.atendidoNombre, _cuidadora);
      },
    );
  });

  group('Repositorio Supabase (con fuente en memoria)', () {
    test(
      'gasto y toma van a sus tablas; el gasto siempre sale pendiente',
      () async {
        final fuente = FuenteTablasEnMemoria();
        final repo = RepositorioCuidadosSupabase(
          fuente: fuente,
          hogarId: 'h1',
          personaId: _cuidadora,
        );
        await repo.registrarGasto(
          GastoCuidado(
            id: 'g1',
            concepto: 'Pañales',
            centavos: 10000,
            fecha: DateTime(2026, 11, 4),
            registradoPor: _cuidadora,
            registradoNombre: 'C',
            estado: EstadoGasto.confirmado,
          ),
        );
        expect(fuente.tabla('cui_gastos').single['estado'], 'pendiente');
        expect((await repo.gastos()).single.estado, EstadoGasto.pendiente);
        await repo.registrarToma(
          Toma(
            id: 't1',
            medicamentoId: 'm',
            programada: DateTime(2026, 11, 4, 8),
            estado: EstadoToma.dado,
            registradaPor: _cuidadora,
            registradaPorNombre: 'C',
            registradaEn: DateTime(2026, 11, 4, 8, 5),
          ),
        );
        expect(fuente.tabla('cui_tomas').single['estado'], 'dado');
        expect(
          (await repo.tomas(DateTime(2026, 11, 4))).single.estado,
          EstadoToma.dado,
        );
      },
    );

    test('perfil: la hermana sale de su fila de autorización', () async {
      final fuente = FuenteTablasEnMemoria();
      fuente.tabla('cui_autorizacion_resumen').add({
        'persona_id': _hermana,
        'autorizado': true,
      });
      final repo = RepositorioCuidadosSupabase(
        fuente: fuente,
        hogarId: 'h1',
        personaId: _hermana,
      );
      final p = await repo.perfil();
      expect(p.esFamiliar && p.resumenAutorizado, isTrue);
    });

    test('resumen: usa la función del servidor', () async {
      final fuente = FuenteTablasEnMemoria();
      fuente.funciones['cui_resumen_mensual'] = (_) => {
        'lineas': [
          {'concepto': 'Cuidadora', 'centavos': 100, 'titular': 'papa'},
        ],
      };
      final repo = RepositorioCuidadosSupabase(
        fuente: fuente,
        hogarId: 'h1',
        personaId: _dueno,
      );
      final r = await repo.resumenMensual(DateTime(2026, 11, 15));
      expect(r!.totalCentavos, 100);
      expect(fuente.llamadas.single.$2['p_mes'], '2026-11-01');
    });
  });

  group('Pantallas', () {
    testWidgets('Mi turno: la cuidadora ve su turno y solo sus accesos', (
      t,
    ) async {
      await _alto(t);
      await t.pumpWidget(
        _app(const PantallaMiTurno(), _datos(), _cuidadora, Rol.cuidador),
      );
      await t.pumpAndSettle();
      expect(find.text('Turno: 07:30 a 18:30'), findsOneWidget);
      expect(find.text('Siguiente medicamento a las 14:00'), findsOneWidget);
      expect(find.text('Medicamentos'), findsOneWidget);
      expect(find.text('Resumen del mes'), findsNothing);
      expect(find.text('Cambio urgente'), findsNothing);
      expect(find.text('Turnos, citas y medicamentos'), findsNothing);
    });

    testWidgets('Mi turno: entrega de turno con notas para quien sigue', (
      t,
    ) async {
      await _alto(t);
      final d = _datos();
      d.entregas.add(
        Entrega(
          id: 'e1',
          dePersonaId: _dueno,
          deNombre: 'Dueño',
          notas: 'Cenó poco',
          creadaEn: DateTime(2026, 11, 4, 7),
        ),
      );
      await t.pumpWidget(
        _app(const PantallaMiTurno(), d, _cuidadora, Rol.cuidador),
      );
      await t.pumpAndSettle();
      expect(find.text('Cenó poco'), findsOneWidget);
      await t.tap(find.text('Dejar notas para quien sigue'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Todo en orden');
      await t.tap(find.text('Guardar'));
      await t.pumpAndSettle();
      expect(d.entregas.length, 2);
      expect(find.text('Todo en orden'), findsOneWidget);
    });

    testWidgets(
      'Mi turno: cambio urgente con "Enterada" y el dueño ve los accesos',
      (t) async {
        await _alto(t);
        final d = _datos();
        d.cambios.add(
          CambioUrgente(
            id: 'c1',
            accion: AccionCambio.suspender,
            nota: 'Hasta nuevo aviso',
            creadoPor: _dueno,
            creadoEn: DateTime(2026, 11, 4, 9),
            medicamentoNombre: 'Medicamento A',
          ),
        );
        await t.pumpWidget(
          _app(const PantallaMiTurno(), d, _cuidadora, Rol.cuidador),
        );
        await t.pumpAndSettle();
        expect(find.text('Hay una indicación nueva'), findsOneWidget);
        await t.tap(find.text('Enterada'));
        await t.pumpAndSettle();
        expect(d.cambios.single.atendido, isTrue);

        await t.pumpWidget(_app(const PantallaMiTurno(), d, _dueno, Rol.dueno));
        await t.pumpAndSettle();
        expect(find.text('Cambio urgente'), findsWidgets);
        expect(find.text('Resumen del mes'), findsOneWidget);
      },
    );

    testWidgets(
      'Medicamentos: tocar marca "Ya se dio" y la confirmación es discreta',
      (t) async {
        await _alto(t);
        final d = _datos();
        await t.pumpWidget(
          _app(const PantallaMedicamentos(), d, _cuidadora, Rol.cuidador),
        );
        await t.pumpAndSettle();
        await t.tap(find.textContaining('08:00'));
        await t.pumpAndSettle();
        await t.tap(find.text('Ya se dio'));
        await t.pumpAndSettle();
        expect(d.tomas.values.single.estado, EstadoToma.dado);
        // El aviso no nombra el medicamento.
        expect(find.text('Registrado'), findsOneWidget);
        final snack = t.widget<SnackBar>(find.byType(SnackBar));
        expect((snack.content as Text).data, isNot(contains('Medicamento')));
      },
    );

    testWidgets('Medicamentos: la hermana solo lee', (t) async {
      await _alto(t);
      await t.pumpWidget(
        _app(
          const PantallaMedicamentos(),
          _datos(),
          _hermana,
          Rol.cuidador,
          perfil: _perfilHermana,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Solo lectura.'), findsOneWidget);
      await t.tap(find.textContaining('08:00'));
      await t.pumpAndSettle();
      expect(find.text('Ya se dio'), findsNothing);
    });

    testWidgets('Medicamentos: la pareja sin consentimiento no ve nada', (
      t,
    ) async {
      await _alto(t);
      await t.pumpWidget(
        _app(
          const PantallaMedicamentos(),
          _datos(),
          _pareja,
          Rol.coadministrador,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Esta sección no está disponible'), findsOneWidget);
      expect(find.textContaining('Medicamento A'), findsNothing);
    });

    testWidgets('Comidas: se registra "Comió poco" en el desayuno', (t) async {
      await _alto(t);
      final d = _datos();
      await t.pumpWidget(
        _app(const PantallaComidas(), d, _cuidadora, Rol.cuidador),
      );
      await t.pumpAndSettle();
      expect(find.text('¿Cómo comió?'), findsNWidgets(4));
      await t.tap(find.text('Comió poco').first);
      await t.pumpAndSettle();
      expect(d.comidas.values.single.tiempo, TiempoComidaPapa.desayuno);
      expect(d.comidas.values.single.resultado, ResultadoComida.comioPoco);
      expect(find.text('Comió poco (registrado)'), findsOneWidget);
    });

    testWidgets(
      'Bitácora: la cuidadora escribe una nota y registra un gasto pendiente',
      (t) async {
        await _alto(t);
        final d = _datos();
        await t.pumpWidget(
          _app(const PantallaBitacora(), d, _cuidadora, Rol.cuidador),
        );
        await t.pumpAndSettle();
        await t.tap(find.text('Nueva nota'));
        await t.pumpAndSettle();
        await t.enterText(find.byType(TextField), 'Papá descansó');
        await t.tap(find.text('Guardar'));
        await t.pumpAndSettle();
        expect(find.text('Papá descansó'), findsOneWidget);

        await t.tap(find.text('Gastos'));
        await t.pumpAndSettle();
        await t.tap(find.text('Registrar gasto'));
        await t.pumpAndSettle();
        await t.enterText(
          find.widgetWithText(TextField, '¿En qué se gastó?'),
          'Pañales',
        );
        await t.enterText(
          find.widgetWithText(TextField, 'Monto en pesos'),
          '185.50',
        );
        await t.tap(find.text('Guardar'));
        await t.pumpAndSettle();
        expect(d.gastos.single.estado, EstadoGasto.pendiente);
        expect(d.gastos.single.centavos, 18550);
        expect(find.text('Pendiente de confirmación'), findsOneWidget);
        expect(find.text('Confirmar'), findsNothing);
      },
    );

    testWidgets('Bitácora: el dueño confirma el gasto', (t) async {
      await _alto(t);
      final d = _datos();
      d.gastos.add(
        GastoCuidado(
          id: 'g1',
          concepto: 'Aseo',
          centavos: 9000,
          fecha: DateTime(2026, 11, 4),
          registradoPor: _cuidadora,
          registradoNombre: 'Cuidadora',
        ),
      );
      await t.pumpWidget(_app(const PantallaBitacora(), d, _dueno, Rol.dueno));
      await t.pumpAndSettle();
      await t.tap(find.text('Gastos'));
      await t.pumpAndSettle();
      await t.tap(find.text('Confirmar'));
      await t.pumpAndSettle();
      expect(d.gastos.single.estado, EstadoGasto.confirmado);
    });

    testWidgets('Resumen: la hermana no ve montos de la pareja ni del dueño', (
      t,
    ) async {
      await _alto(t);
      await t.pumpWidget(
        _app(
          const PantallaResumenMensual(),
          _datos(),
          _hermana,
          Rol.cuidador,
          perfil: _perfilHermana,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Pago de la cuidadora'), findsOneWidget);
      expect(find.text('Gasto de la pareja'), findsNothing);
      expect(find.text('Gasto del dueño'), findsNothing);
    });

    testWidgets(
      'Resumen: sin autorización del albacea, ni lo intenta mostrar',
      (t) async {
        await _alto(t);
        await t.pumpWidget(
          _app(
            const PantallaResumenMensual(),
            _datos(),
            _hermana,
            Rol.cuidador,
            perfil: const PerfilCuidados(esFamiliar: true),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Pago de la cuidadora'), findsNothing);
        expect(find.textContaining('autorice'), findsOneWidget);
      },
    );

    testWidgets('Resumen: el dueño lo ve completo', (t) async {
      await _alto(t);
      await t.pumpWidget(
        _app(const PantallaResumenMensual(), _datos(), _dueno, Rol.dueno),
      );
      await t.pumpAndSettle();
      expect(find.text('Gasto de la pareja'), findsOneWidget);
      expect(find.text('Gasto del dueño'), findsOneWidget);
    });

    testWidgets('Resumen: la cuidadora no tiene acceso', (t) async {
      await _alto(t);
      await t.pumpWidget(
        _app(
          const PantallaResumenMensual(),
          _datos(),
          _cuidadora,
          Rol.cuidador,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Pago de la cuidadora'), findsNothing);
      expect(find.text('Esta sección no está disponible'), findsOneWidget);
    });
  });

  group('Nada clínico sale a IA ni a bocinas (criterio 6)', () {
    test('el módulo no toca herramientas, asistente, avisos ni voz', () {
      final prohibidos = [
        'herramientas',
        'gravity/',
        'avisos',
        'voz',
        'asistente',
        'http',
      ];
      final archivos = Directory('lib/modulos/cuidados')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(archivos, isNotEmpty);
      for (final f in archivos) {
        for (final linea in f.readAsLinesSync().where(
          (l) => l.startsWith('import '),
        )) {
          for (final p in prohibidos) {
            expect(linea.contains("/$p"), isFalse, reason: '${f.path}: $linea');
          }
        }
      }
    });

    test('el texto genérico de recordatorio no lleva nombres ni cifras', () {
      expect(RegExp(r'\d').hasMatch(textoRecordatorioGenerico), isFalse);
      expect(
        textoRecordatorioGenerico.toLowerCase().contains('medicamento'),
        isFalse,
      );
    });
  });
}

/// Repositorio que devuelve el resumen sin filtrar, para probar la defensa
/// doble de la app.
class _RepoSinFiltro extends RepositorioCuidadosEnMemoria {
  _RepoSinFiltro(RepositorioCuidadosEnMemoria base)
    : super(datos: base.datos, personaId: base.personaId, rol: Rol.dueno);
}
