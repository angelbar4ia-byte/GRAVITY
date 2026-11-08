// Revisión Fase 5: F5-I2 (reintento a Finanzas), F5-I3 (toma pospuesta que
// recibe otra persona) y F5-M6 (títulos sin nombre).
import 'package:finanzas_dominio/finanzas_dominio.dart' show Categoria;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/diseno/proveedores.dart' show RelojFijo, relojProvider;
import 'package:gravity/modulos/cuidados/casos_uso/permisos_cuidados.dart';
import 'package:gravity/modulos/cuidados/casos_uso/servicio_cuidados.dart';
import 'package:gravity/modulos/cuidados/datos/modelos.dart';
import 'package:gravity/modulos/cuidados/datos/repositorio.dart';
import 'package:gravity/modulos/cuidados/estado/proveedores.dart';
import 'package:gravity/modulos/cuidados/pantallas/bitacora.dart';
import 'package:gravity/modulos/cuidados/pantallas/medicamentos.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/ids.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/nucleo/avisos/catalogo_avisos.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

import '../finanzas/ayuda_finanzas.dart';

final _ahora = DateTime(2026, 11, 11, 19);

RepositorioFinanzasEnMemoria _finanzas() {
  final base = datosDeDemostracion(hoy: hoyDePrueba);
  final salud = base.categorias.firstWhere((x) => x.nombre == 'Salud');
  return RepositorioFinanzasEnMemoria(
    datos: base.copiar(
      categorias: [
        ...base.categorias,
        Categoria(
          id: 'cat-cuidados',
          padreId: salud.id,
          nivel: 2,
          nombre: 'Cuidados de largo plazo y paliativos',
        ),
      ],
    ),
    personaId: IdsDemostracion.dueno,
    reloj: () => ahoraDePrueba,
  );
}

/// Servicio del dueño cuyo paso a Finanzas falla las primeras [fallos] veces.
({ServicioCuidados srv, RepositorioFinanzasEnMemoria fin, List<int> llamadas})
_dueno(DatosCuidadosMemoria d, {int fallos = 0}) {
  final fin = _finanzas();
  final llamadas = <int>[];
  final srv = ServicioCuidados(
    RepositorioCuidadosEnMemoria(
      datos: d,
      personaId: 'persona-dueno',
      rol: Rol.dueno,
    ),
    permisos: const PermisosCuidados(rol: Rol.dueno),
    personaId: 'persona-dueno',
    nombre: 'Dueño',
    ahora: () => _ahora,
    alConfirmarGasto: (g, {libroCompartidoId}) async {
      llamadas.add(1);
      if (llamadas.length <= fallos) throw StateError('sin Finanzas');
      await pasarGastoAFinanzas(fin, g, confirmadoPor: IdsDemostracion.dueno);
    },
    constaEnFinanzas: (g) async => fin.actual.datos.movimientos.any(
      (m) => m.id == idEstable(ClavesId.gastoCuidado(g.id)),
    ),
  );
  return (srv: srv, fin: fin, llamadas: llamadas);
}

void main() {
  group('F5-I2 reintento del paso a Finanzas', () {
    test('falla Finanzas, se reintenta y queda un solo movimiento', () async {
      final d = datosDeEjemploCuidados(_ahora);
      final x = _dueno(d, fallos: 1);
      await x.srv.registrarGasto(concepto: 'Pañales', centavos: 18550);
      final id = (await x.srv.gastos()).firstWhere((g) => g.concepto == 'Pañales').id;
      final antes = x.fin.actual.datos.movimientos.length;

      expect(await x.srv.resolverGasto(id, confirmar: true), avisoGastoSinFinanzas);
      expect(await x.srv.gastosSinFinanzas(), {id});
      expect(x.fin.actual.datos.movimientos.length, antes);

      // Reintento: no vuelve a confirmar en el servidor (seguiría confirmado).
      expect(await x.srv.pasarGastoAFinanzas(id), isNull);
      expect(x.fin.actual.datos.movimientos.length, antes + 1);
      expect(await x.srv.gastosSinFinanzas(), isEmpty);
      expect(
        (await x.srv.gastos()).firstWhere((g) => g.id == id).estado,
        EstadoGasto.confirmado,
      );

      // Repetir es éxito (yaRegistrado) y no duplica.
      expect(await x.srv.pasarGastoAFinanzas(id), isNull);
      expect(x.fin.actual.datos.movimientos.length, antes + 1);
    });

    test('si el reintento falla otra vez, avisa y sigue ofreciéndose', () async {
      final d = datosDeEjemploCuidados(_ahora);
      final x = _dueno(d, fallos: 2);
      await x.srv.registrarGasto(concepto: 'Gasas', centavos: 9000);
      final id = (await x.srv.gastos()).firstWhere((g) => g.concepto == 'Gasas').id;
      await x.srv.resolverGasto(id, confirmar: true);
      expect(await x.srv.pasarGastoAFinanzas(id), avisoGastoSinFinanzas);
      expect(await x.srv.gastosSinFinanzas(), {id});
    });

    test('solo el dueño; un gasto pendiente no se pasa', () async {
      final d = datosDeEjemploCuidados(_ahora);
      final cui = ServicioCuidados(
        RepositorioCuidadosEnMemoria(
          datos: d,
          personaId: 'persona-cuidadora',
          rol: Rol.cuidador,
        ),
        permisos: const PermisosCuidados(rol: Rol.cuidador),
        personaId: 'persona-cuidadora',
        nombre: 'Cuidadora',
        ahora: () => _ahora,
        constaEnFinanzas: (_) async => false,
      );
      await cui.registrarGasto(concepto: 'Guantes', centavos: 500);
      final id = (await cui.gastos()).first.id;
      expect(await cui.gastosSinFinanzas(), isEmpty);
      expect(
        () => cui.pasarGastoAFinanzas(id),
        throwsA(isA<ErrorCuidados>()),
      );
      final x = _dueno(d);
      await expectLater(
        x.srv.pasarGastoAFinanzas(id),
        throwsA(isA<ErrorCuidados>()),
      );
      expect(x.llamadas, isEmpty);
    });

    testWidgets('la tarjeta ofrece "Pasar a Finanzas" solo al dueño', (t) async {
      final d = datosDeEjemploCuidados(_ahora);
      final x = _dueno(d, fallos: 1);
      await x.srv.registrarGasto(concepto: 'Pañales', centavos: 18550);
      final id = (await x.srv.gastos()).firstWhere((g) => g.concepto == 'Pañales').id;
      await x.srv.resolverGasto(id, confirmar: true);

      await t.binding.setSurfaceSize(const Size(400, 3000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      Widget app(String persona, Rol rol, ServicioCuidados srv) => ProviderScope(
        overrides: [
          relojProvider.overrideWithValue(RelojFijo(_ahora)),
          almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
          servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
          sesionEfectivaProvider.overrideWithValue(
            Sesion(persona: Persona(id: persona, nombre: persona), rol: rol),
          ),
          repositorioCuidadosProvider.overrideWithValue(
            RepositorioCuidadosEnMemoria(
              datos: d,
              personaId: persona,
              rol: rol,
            ),
          ),
          servicioCuidadosProvider.overrideWithValue(srv),
        ],
        child: const MaterialApp(home: PantallaBitacora()),
      );

      await t.pumpWidget(app('persona-dueno', Rol.dueno, x.srv));
      await t.pumpAndSettle();
      await t.tap(find.text('Gastos'));
      await t.pumpAndSettle();
      expect(find.text('Pasar a Finanzas'), findsOneWidget);
      await t.tap(find.text('Pasar a Finanzas'));
      await t.pumpAndSettle();
      expect(find.text('Pasar a Finanzas'), findsNothing);
      expect(find.text('Gasto pasado a Finanzas'), findsOneWidget);
      expect(x.llamadas.length, 2);
    });
  });

  group('F5-I3 toma pospuesta', () {
    // La toma de las 20:00 del miércoles se pospone a la cuidadora, que
    // entra el jueves a las 7:30.
    DatosCuidadosMemoria datosConPospuesta() {
      final d = datosDeEjemploCuidados(_ahora);
      final id = d.tomas.keys.firstWhere(
        (k) => d.tomas[k]!.programada == DateTime(2026, 11, 11, 20),
      );
      final t = d.tomas[id]!;
      d.tomas[id] = Toma(
        id: id,
        medicamentoId: t.medicamentoId,
        programada: t.programada,
        estado: EstadoToma.pendiente,
        registradaPor: '',
        registradaPorNombre: '',
        registradaEn: t.programada,
        pospuestaA: 'persona-cuidadora',
        pospuestaTurnoEn: DateTime(2026, 11, 12, 7, 30),
      );
      return d;
    }

    test('la toma aparece el día del turno que la recibe', () async {
      final d = datosConPospuesta();
      final srv = ServicioCuidados(
        RepositorioCuidadosEnMemoria(
          datos: d,
          personaId: 'persona-cuidadora',
          rol: Rol.cuidador,
        ),
        permisos: const PermisosCuidados(rol: Rol.cuidador),
        personaId: 'persona-cuidadora',
        nombre: 'Cuidadora',
        ahora: () => _ahora,
      );
      final jueves = await srv.dosisDelDia(DateTime(2026, 11, 12));
      final pospuestas = jueves.where((x) => x.toma?.pospuestaA != null);
      expect(pospuestas, hasLength(1));
      expect(pospuestas.single.hora, DateTime(2026, 11, 11, 20));
      expect(pospuestas.single.estado, EstadoToma.pendiente);
    });

    testWidgets('quien la recibe la ve como pospuesta por otra persona', (
      t,
    ) async {
      final d = datosConPospuesta();
      await t.binding.setSurfaceSize(const Size(400, 3000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            relojProvider.overrideWithValue(RelojFijo(_ahora)),
            almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
            servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
            sesionEfectivaProvider.overrideWithValue(
              const Sesion(
                persona: Persona(
                  id: 'persona-cuidadora',
                  nombre: 'Cuidadora',
                ),
                rol: Rol.cuidador,
              ),
            ),
            repositorioCuidadosProvider.overrideWithValue(
              RepositorioCuidadosEnMemoria(
                datos: d,
                personaId: 'persona-cuidadora',
                rol: Rol.cuidador,
              ),
            ),
          ],
          child: const MaterialApp(home: PantallaMedicamentos()),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.textContaining('Pospuesta por otra persona de turno'),
        findsOneWidget,
      );
    });
  });

  test('F5-M6: los títulos de Cuidados no llevan nombres', () {
    for (final tipo in [
      'recordatorio_toma',
      'recordatorio_comida',
      'entrega_turno',
      'cambio_urgente_cuidados',
    ]) {
      expect(titulosDeAviso[tipo], isNot(contains('Papá')));
    }
    expect(titulosDeAviso['recordatorio_toma'], 'Hora de un recordatorio de cuidado');
  });
}
