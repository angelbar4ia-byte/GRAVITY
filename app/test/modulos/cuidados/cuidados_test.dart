import 'package:gravity/nucleo/cuidados/turnos.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/diseno/formato.dart' show formatearCentavos;
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
      // v1.2: la hermana marca tomas en su turno (la hora la valida marcaTomaA).
      expect(her.marcaToma, isTrue);
      expect(her.registraComida, isFalse);
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
      expect(con.veBitacora, isTrue);
      expect(con.veResumen, isFalse);
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
        // Marcar dos veces no duplica: la toma es la misma fila.
        final total = d.tomas.length;
        await s.marcarToma(antes.first, dado: true);
        expect(d.tomas.length, total);
        expect(
          d.tomas.values.where((t) => t.estado != EstadoToma.pendiente).length,
          2,
        );
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
        ).marcarToma(toma),
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
    test('cada cuidadora ve solo lo suyo; el dueño ve todo; la pareja con consentimiento también', () async {
      final d = _datos();
      final c = _srv(d, _cuidadora, Rol.cuidador);
      final h = _srv(d, _hermana, Rol.cuidador, perfil: _perfilHermana);
      final o = _srv(d, _dueno, Rol.dueno);
      await c.agregarNota('Papá durmió bien');
      await h.agregarNota('Visita por la tarde');
      expect((await c.bitacora()).map((e) => e.texto), ['Papá durmió bien']);
      expect((await h.bitacora()).map((e) => e.texto), ['Visita por la tarde']);
      expect((await o.bitacora()).length, 2);
      final p = _srv(
        d,
        _pareja,
        Rol.coadministrador,
        perfil: const PerfilCuidados(consentimiento: true),
      );
      // Con su consentimiento la pareja lee la bitácora entera (v1.2, §8d);
      // sin él, nada (lo cubre instrucciones_consentimientos_test.dart).
      expect(await p.bitacora(), hasLength(2));
    });

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
        expect(
          (await o.gastos()).firstWhere((x) => x.id == g.id).estado,
          EstadoGasto.pendiente,
        );
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
        // Solo gastos confirmados, sin los de la pareja ni los del dueño.
        expect(r!.gastosCuidadoCentavos, 1200000 + 180000);
        expect(r.gastosCasaCentavos, 350000);
        expect(r.nGastos, 3);
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
        // El servidor excluye lo de la pareja y lo del dueño también para el
        // dueño (spec §4): ve los mismos totales que la hermana.
        final o = await _srv(d, _dueno, Rol.dueno).resumen(mes);
        expect(o!.totalCentavos, 1200000 + 180000 + 350000);
        expect(o.nGastos, 3);
      },
    );

    test('solo cuentan los gastos confirmados del mes', () async {
      final d = _datos();
      final c = _srv(d, _cuidadora, Rol.cuidador);
      final o = _srv(d, _dueno, Rol.dueno);
      await c.registrarGasto(concepto: 'Aseo', centavos: 5000);
      // La cuidadora solo registra cuidado; el gasto de casa lo hace la hermana.
      final h = _srv(d, _hermana, Rol.cuidador, perfil: _perfilHermana);
      await h.registrarGasto(
        concepto: 'Luz',
        centavos: 7000,
        ambito: AmbitoGasto.casa,
      );
      expect((await o.resumen(mes))!.nGastos, 3); // pendientes: no cuentan
      for (final g in await o.gastos()) {
        if (g.estado == EstadoGasto.pendiente) {
          await o.resolverGasto(g.id, confirmar: true);
        }
      }
      final r = (await o.resumen(mes))!;
      expect(r.gastosCuidadoCentavos, 1200000 + 180000 + 5000);
      expect(r.gastosCasaCentavos, 350000 + 7000);
      expect(r.nGastos, 5);
    });
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
        final recibido = (await c.cambiosUrgentes()).single;
        // El servidor avisa a quien está de turno (miércoles 10:00).
        expect(recibido.paraPersonaId, _cuidadora);
        expect(recibido.texto, startsWith('Suspender: Medicamento A'));
        await c.atenderCambio(recibido.id);
        final visto = (await o.cambiosUrgentes()).single;
        expect(visto.atendido, isTrue);
        expect(visto.atendidoNombre, _cuidadora);
      },
    );
  });

  group('Repositorio Supabase (con fuente en memoria)', () {
    RepositorioCuidadosSupabase repo(FuenteTablasEnMemoria f, String quien) =>
        RepositorioCuidadosSupabase(fuente: f, hogarId: 'h1', personaId: quien);

    test('gasto: solo manda las columnas del servidor, sin persona ni estado', () async {
      final fuente = FuenteTablasEnMemoria();
      final r = repo(fuente, _cuidadora);
      await r.registrarGasto(
        GastoCuidado(
          id: 'g1',
          concepto: 'Pañales',
          centavos: 10000,
          fecha: DateTime(2026, 11, 4),
          registradoPor: _cuidadora,
          registradoNombre: 'C',
          estado: EstadoGasto.confirmado,
          ambito: AmbitoGasto.casa,
        ),
      );
      final fila = fuente.tabla('cui_gastos').single;
      expect(fila.keys.toSet(), {
        'id',
        'hogar_id',
        'monto_centavos',
        'concepto',
        'fecha',
        'ambito',
      });
      expect(fila['monto_centavos'], 10000);
      expect(fila['ambito'], 'casa');
      // Lo que devuelve el servidor: pendiente y a nombre de quien lo registró.
      fila
        ..['persona_id'] = _cuidadora
        ..['estado'] = 'pendiente_confirmacion';
      final g = (await r.gastos()).single;
      expect(g.estado, EstadoGasto.pendiente);
      expect(g.registradoPor, _cuidadora);
      expect(g.ambito, AmbitoGasto.casa);
    });

    test('toma: se marca con cui_marcar_toma, no con update directo', () async {
      final fuente = FuenteTablasEnMemoria();
      final hora = DateTime(2026, 11, 4, 8);
      fuente.tabla('cui_tomas').add({
        'id': 'toma-servidor',
        'medicamento_id': 'm',
        'programada_para': hora.toUtc().toIso8601String(),
        'estado': 'pendiente',
        'marcada_por': null,
        'marcada_en': null,
      });
      final r = repo(fuente, _cuidadora);
      expect(
        (await r.tomas(DateTime(2026, 11, 4))).single.estado,
        EstadoToma.pendiente,
      );
      await r.marcarToma(
        Toma(
          id: 'ignorado',
          medicamentoId: 'm',
          programada: hora,
          estado: EstadoToma.dado,
          registradaPor: _cuidadora,
          registradaPorNombre: 'C',
          registradaEn: hora,
        ),
      );
      expect(fuente.llamadas.last.$1, 'cui_marcar_toma');
      expect(fuente.llamadas.last.$2, {
        'p_toma_id': 'toma-servidor',
        'p_estado': 'dado',
      });
      expect(fuente.tabla('cui_tomas').single['estado'], 'pendiente');
    });

    test(
      'perfil: sale de cui_perfil; la hermana, de su autorización',
      () async {
        final fuente = FuenteTablasEnMemoria();
        fuente.funciones['cui_perfil'] = (p) {
          expect(p, {'p_hogar_id': 'h1'});
          return 'hermana';
        };
        fuente.tabla('cui_autorizacion_resumen').add({
          'persona_id': _hermana,
          'vigente': true,
        });
        final p = await repo(fuente, _hermana).perfil();
        expect(p.esFamiliar && p.resumenAutorizado, isTrue);
        // El tipo de sus turnos, no el rol de membresía, decide.
        final permisos = PermisosCuidados(rol: Rol.familiar, perfil: p);
        expect(permisos.entra && permisos.resumenDisponible, isTrue);
        expect(permisos.marcaTomaA(RolDeTurno.cuidadoraPrincipal), isFalse);
        expect(permisos.marcaTomaA(RolDeTurno.hermana), isTrue);

        fuente.funciones['cui_perfil'] = (_) => null;
        final sin = await repo(fuente, _hermana).perfil();
        expect(sin.sinAcceso, isTrue);
        expect(PermisosCuidados(rol: Rol.cuidador, perfil: sin).entra, isFalse);
      },
    );

    test('turnos: el horario semanal se expande a los días pedidos', () async {
      final fuente = FuenteTablasEnMemoria();
      fuente.tabla('cui_turnos').addAll([
        {
          'id': 't1',
          'persona_id': _cuidadora,
          'dia_semana': 3, // miércoles
          'inicio_min': 450,
          'fin_min': 1110,
          'tipo': 'cuidadora',
        },
        {
          'id': 't2',
          'persona_id': _hermana,
          'dia_semana': 2, // martes
          'inicio_min': 900,
          'fin_min': 1440,
          'tipo': 'hermana_visita',
        },
      ]);
      final r = repo(fuente, _dueno);
      final semana = await r.turnos(
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 9),
      );
      expect(semana.length, 2);
      expect(semana[0].funcion, FuncionTurno.hermanaVisita);
      expect(semana[0].horario, '15:00 a 00:00');
      expect(semana[0].fin, DateTime(2026, 11, 4));
      expect(semana[1].horario, '07:30 a 18:30');
      expect(semana[1].inicio, DateTime(2026, 11, 4, 7, 30));
      // Una semana después, el mismo horario.
      expect(
        (await r.turnos(DateTime(2026, 11, 9), DateTime(2026, 11, 16))).length,
        2,
      );
    });

    test('comida, bitácora y entrega: solo las columnas con permiso', () async {
      final fuente = FuenteTablasEnMemoria();
      final r = repo(fuente, _cuidadora);
      await r.registrarComida(
        ComidaRegistro(
          id: 'c1',
          fecha: DateTime(2026, 11, 4),
          tiempo: TiempoComidaPapa.desayuno,
          resultado: ResultadoComida.comioPoco,
          registradaPor: _cuidadora,
          registradaPorNombre: 'C',
          registradaEn: _miercoles10,
        ),
      );
      await r.agregarBitacora(
        EntradaBitacora(
          id: 'b1',
          tipo: TipoBitacora.nota,
          texto: 'Revisión',
          autorId: _cuidadora,
          autorNombre: 'C',
          creadaEn: _miercoles10,
        ),
      );
      await r.dejarEntrega(
        Entrega(
          id: 'e1',
          dePersonaId: _cuidadora,
          deNombre: 'C',
          notas: 'Todo bien',
          creadaEn: _miercoles10,
          paraPersonaId: _dueno,
        ),
      );
      expect(fuente.tabla('cui_comidas').single.keys.toSet(), {
        'id',
        'hogar_id',
        'fecha',
        'tiempo',
        'resultado',
      });
      expect(fuente.tabla('cui_comidas').single['resultado'], 'comio_poco');
      expect(fuente.tabla('cui_bitacora').single.keys.toSet(), {
        'id',
        'hogar_id',
        'nota',
      });
      expect(fuente.tabla('cui_bitacora').single['nota'], 'Revisión');
      expect(fuente.tabla('cui_entregas').single.keys.toSet(), {
        'id',
        'hogar_id',
        'para_persona',
        'nota',
      });
      fuente.tabla('cui_bitacora').single
        ..['persona_id'] = _cuidadora
        ..['creada_en'] = _miercoles10.toUtc().toIso8601String();
      final e = (await r.bitacora()).single;
      expect(e.tipo, TipoBitacora.nota);
      expect(e.texto, 'Revisión');
    });

    test('cambio urgente, gasto y permisos: por RPC', () async {
      final fuente = FuenteTablasEnMemoria();
      final r = repo(fuente, _dueno);
      await r.crearCambioUrgente(
        CambioUrgente(
          id: 'u1',
          texto: 'Suspender: A',
          creadoPor: _dueno,
          creadoEn: _miercoles10,
        ),
      );
      await r.atenderCambioUrgente(
        'u1',
        personaId: _dueno,
        nombre: 'D',
        en: _miercoles10,
      );
      await r.resolverGasto('g1', EstadoGasto.rechazado);
      await r.cambiarConsentimiento(_pareja, true);
      await r.autorizarResumen(_hermana, false);
      await r.generarTomas(DateTime(2026, 11, 4, 15), dias: 3);
      expect(fuente.llamadas.map((l) => l.$1), [
        'cui_crear_cambio_urgente',
        'cui_atender_cambio_urgente',
        'cui_confirmar_gasto',
        'cui_cambiar_consentimiento',
        'cui_autorizar_resumen',
        'cui_generar_tomas',
      ]);
      expect(fuente.llamadas[0].$2, {
        'p_hogar_id': 'h1',
        'p_texto': 'Suspender: A',
        'p_id': 'u1',
      });
      expect(fuente.llamadas[2].$2, {'p_gasto_id': 'g1', 'p_confirmar': false});
      expect(fuente.llamadas[3].$2, {
        'p_hogar_id': 'h1',
        'p_persona_id': _pareja,
        'p_concedido': true,
      });
      expect(fuente.llamadas[4].$2['p_vigente'], false);
      expect(fuente.llamadas[5].$2, {
        'p_hogar_id': 'h1',
        'p_desde': '2026-11-04',
        'p_dias': 3,
      });
      for (final t in [
        'cui_cambios_urgentes',
        'cui_gastos',
        'cui_consentimientos',
        'cui_autorizacion_resumen',
      ]) {
        expect(fuente.tabla(t), isEmpty, reason: 'no se escribe $t directo');
      }
    });

    test(
      'resumen: usa la función del servidor (un renglón por hogar)',
      () async {
        final fuente = FuenteTablasEnMemoria();
        fuente.funciones['cui_resumen_mensual'] = (_) => [
          {
            'hogar_id': 'otro',
            'mes': '2026-11-01',
            'gastos_cuidado_centavos': 1,
            'gastos_casa_centavos': 1,
            'n_gastos': 1,
          },
          {
            'hogar_id': 'h1',
            'mes': '2026-11-01',
            'gastos_cuidado_centavos': 100,
            'gastos_casa_centavos': 50,
            'n_gastos': 2,
          },
        ];
        final r = await repo(
          fuente,
          _dueno,
        ).resumenMensual(DateTime(2026, 11, 15));
        expect(r!.gastosCuidadoCentavos, 100);
        expect(r.gastosCasaCentavos, 50);
        expect(r.nGastos, 2);
        expect(fuente.llamadas.single.$2['p_mes'], '2026-11-01');
      },
    );

    test('resumen y conteos del día de Papá', () async {
      final fuente = FuenteTablasEnMemoria();
      fuente.funciones['cui_resumen_papa'] = (_) => [
        {
          'dia': '2026-11-04',
          'tomas_total': 3,
          'tomas_dadas': 1,
          'tomas_no_dadas': 1,
          'tomas_pendientes': 1,
          'comidas_registradas': 2,
          'comidas_con_rechazo': 1,
        },
      ];
      final p = await repo(fuente, _pareja).resumenPapa(DateTime(2026, 11, 4));
      expect(p!.tomasTotal, 3);
      expect(p.comidasConRechazo, 1);
      expect(fuente.llamadas.single.$2, {
        'p_hogar_id': 'h1',
        'p_dia': '2026-11-04',
      });
    });
  });

  group('Mismas reglas que el servidor (repositorio en memoria)', () {
    test(
      'la cuidadora solo marca si estaba de turno a la hora de la toma',
      () async {
        final d = _datos();
        final s = _srv(d, _cuidadora, Rol.cuidador);
        final dosis = await s.dosisDelDia();
        final de20 = dosis.firstWhere((x) => x.hora.hour == 20);
        // 20:00 del miércoles: su turno terminó a las 18:30 (42501).
        expect(
          () => s.marcarToma(de20, dado: true),
          throwsA(isA<ErrorCuidados>()),
        );
        // El dueño sí marca a cualquier hora.
        await _srv(d, _dueno, Rol.dueno).marcarToma(de20, dado: true);
        expect(
          (await _srv(d, _dueno, Rol.dueno).dosisDelDia()).last.estado,
          EstadoToma.dado,
        );
      },
    );

    test('la hermana de turno el martes por la tarde solo lee (decisión pendiente a)', () async {
      final d = _datos(_martes16);
      final her = _srv(
        d,
        _hermana,
        Rol.familiar,
        perfil: PerfilCuidados.servidor('hermana'),
        ahora: _martes16,
      );
      final dosis = (await her.dosisDelDia()).firstWhere(
        (x) => x.hora.hour == 20,
      );
      expect(
        () => her.marcarToma(dosis, dado: true),
        throwsA(isA<ErrorCuidados>()),
      );
      // Pero sí entra y lee, aunque su rol sea familiar: manda el perfil.
      expect(dosis.medicamento.nombre, isNotEmpty);
    });

    test('la toma solo existe si el servidor la generó', () async {
      final d = _datos();
      d.tomas.clear();
      final s = _srv(d, _dueno, Rol.dueno);
      final dosis = (await s.dosisDelDia()).first;
      expect(
        () => s.marcarToma(dosis, dado: true),
        throwsA(isA<ErrorCuidados>()),
      );
      expect(await s.generarTomas(), 3);
      expect(await s.generarTomas(), 0); // idempotente
      await s.marcarToma((await s.dosisDelDia()).first, dado: true);
    });

    test('la entrega es para quien sigue y la leen solo su autora y su destinataria', () async {
      final d = _datos();
      final c = _srv(d, _cuidadora, Rol.cuidador);
      await c.dejarEntrega('Todo en orden');
      final e = d.entregas.single;
      expect(e.dePersonaId, _cuidadora);
      expect(e.paraPersonaId, _dueno);
      expect(
        await _srv(
          d,
          _hermana,
          Rol.cuidador,
          perfil: _perfilHermana,
        ).ultimaEntrega(),
        isNull,
      );
      expect(
        (await _srv(d, _dueno, Rol.dueno).ultimaEntrega())!.notas,
        'Todo en orden',
      );
    });

    test(
      'la comida corregida es una fila nueva y vale la más reciente',
      () async {
        final d = _datos();
        final s = _srv(d, _cuidadora, Rol.cuidador);
        await s.registrarComida(TiempoComidaPapa.cena, ResultadoComida.rechazo);
        await s.registrarComida(TiempoComidaPapa.cena, ResultadoComida.comio);
        expect(d.comidas.length, 2);
        expect(
          (await s.comidasDeHoy())[TiempoComidaPapa.cena]!.resultado,
          ResultadoComida.comio,
        );
        final r = await _repo(
          d,
          _pareja,
          Rol.coadministrador,
        ).resumenPapa(_miercoles10);
        expect(r!.comidasRegistradas, 1);
        expect(r.comidasConRechazo, 0);
      },
    );

    test('la pareja: turnos y conteos del día sin consentimiento; lo clínico con él', () async {
      final d = _datos();
      final sin = _srv(d, _pareja, Rol.coadministrador);
      expect((await sin.turnosDeLaSemana()), isNotEmpty);
      expect((await sin.resumenDelDia())!.tomasTotal, 3);
      expect(await sin.dosisDelDia(), isEmpty);
      await sin.cambiarMiConsentimiento(true);
      final con = _srv(
        d,
        _pareja,
        Rol.coadministrador,
        perfil: await _repo(d, _pareja, Rol.coadministrador).perfil(),
      );
      expect((await con.dosisDelDia()), isNotEmpty);
      expect(await con.bitacora(), isEmpty);
    });

    test('solo el albacea autoriza el resumen de la hermana', () async {
      final d = _datos();
      final sinAut = _repo(
        d,
        _hermana,
        Rol.cuidador,
        perfil: const PerfilCuidados(esFamiliar: true),
      );
      expect(await sinAut.resumenMensual(DateTime(2026, 11)), isNull);
      expect(
        () => _repo(d, _dueno, Rol.dueno).autorizarResumen(_hermana, true),
        throwsA(isA<ErrorCuidados>()),
      );
      await RepositorioCuidadosEnMemoria(
        datos: d,
        personaId: _dueno,
        rol: Rol.dueno,
        esAlbacea: true,
      ).autorizarResumen(_hermana, true);
      expect(await sinAut.resumenMensual(DateTime(2026, 11)), isNotNull);
    });

    test('solo el dueño resuelve gastos, y una sola vez', () async {
      final d = _datos();
      final c = _srv(d, _cuidadora, Rol.cuidador);
      await c.registrarGasto(concepto: 'Aseo', centavos: 100);
      final id = d.gastos.last.id;
      final o = _repo(d, _dueno, Rol.dueno);
      await o.resolverGasto(id, EstadoGasto.rechazado);
      expect(
        () => o.resolverGasto(id, EstadoGasto.confirmado),
        throwsA(isA<ErrorCuidados>()),
      );
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
          paraPersonaId: _cuidadora,
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
            texto: 'Suspender: Medicamento A. Hasta nuevo aviso',
            creadoPor: _dueno,
            creadoEn: DateTime(2026, 11, 4, 9),
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
        expect(
          d.tomas.values.where((x) => x.estado == EstadoToma.dado).length,
          1,
        );
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
        expect(d.gastos.last.estado, EstadoGasto.pendiente);
        expect(d.gastos.last.centavos, 18550);
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
      expect(
        d.gastos.firstWhere((g) => g.id == 'g1').estado,
        EstadoGasto.confirmado,
      );
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
      // Solo totales; lo de la pareja y el dueño (165,000) no está sumado.
      expect(find.text('Cuidado de Papá'), findsOneWidget);
      expect(find.text(formatearCentavos(1380000)), findsOneWidget);
      expect(find.text(formatearCentavos(350000)), findsOneWidget);
      expect(find.text(formatearCentavos(1730000)), findsOneWidget);
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

    testWidgets('Resumen: el dueño ve los mismos totales confirmados', (
      t,
    ) async {
      await _alto(t);
      await t.pumpWidget(
        _app(const PantallaResumenMensual(), _datos(), _dueno, Rol.dueno),
      );
      await t.pumpAndSettle();
      // Mismos totales que la hermana: el servidor excluye lo de la pareja y
      // lo del dueño para todos (spec §4).
      expect(find.text(formatearCentavos(1730000)), findsOneWidget);
      expect(find.text('Gasto de la pareja'), findsNothing);
      expect(find.text('Gasto del dueño'), findsNothing);
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
      expect(find.text('Cuidado de Papá'), findsNothing);
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
