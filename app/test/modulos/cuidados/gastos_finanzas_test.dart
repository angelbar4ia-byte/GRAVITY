// Gastos de cuidado: paso a Finanzas al confirmar y selector de ámbito.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_dominio/finanzas_dominio.dart' show Categoria;
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/diseno/proveedores.dart' show RelojFijo, relojProvider;
import 'package:gravity/modulos/cuidados/casos_uso/permisos_cuidados.dart';
import 'package:gravity/modulos/cuidados/casos_uso/servicio_cuidados.dart';
import 'package:gravity/modulos/cuidados/datos/modelos.dart';
import 'package:gravity/modulos/cuidados/datos/repositorio.dart';
import 'package:gravity/modulos/cuidados/estado/proveedores.dart';
import 'package:gravity/modulos/cuidados/pantallas/bitacora.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

import '../finanzas/ayuda_finanzas.dart';

final _ahora = DateTime(2026, 11, 4, 10);
const _perfilHermana = PerfilCuidados(
  esFamiliar: true,
  resumenAutorizado: true,
);

ServicioCuidados _srv(
  DatosCuidadosMemoria d,
  String id,
  Rol rol, {
  PerfilCuidados perfil = const PerfilCuidados(),
  PasarGastoAFinanzas? alConfirmar,
}) => ServicioCuidados(
  RepositorioCuidadosEnMemoria(
    datos: d,
    personaId: id,
    rol: rol,
    perfilActual: perfil,
  ),
  permisos: PermisosCuidados(rol: rol, perfil: perfil),
  personaId: id,
  nombre: id,
  ahora: () => _ahora,
  alConfirmarGasto: alConfirmar,
);

Widget _app(
  DatosCuidadosMemoria d,
  String id,
  Rol rol,
  PerfilCuidados perfil,
) => ProviderScope(
  overrides: [
    relojProvider.overrideWithValue(RelojFijo(_ahora)),
    almacenSeguroProvider.overrideWithValue(AlmacenSeguroEnMemoria()),
    servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
    sesionEfectivaProvider.overrideWithValue(
      Sesion(
        persona: Persona(id: id, nombre: id),
        rol: rol,
      ),
    ),
    repositorioCuidadosProvider.overrideWithValue(
      RepositorioCuidadosEnMemoria(
        datos: d,
        personaId: id,
        rol: rol,
        perfilActual: perfil,
      ),
    ),
  ],
  child: const MaterialApp(home: PantallaBitacora()),
);

void main() {
  test('confirmar llama a Finanzas una vez; rechazar no', () async {
    final d = datosDeEjemploCuidados(_ahora);
    final llamadas = <GastoCuidado>[];
    final c = _srv(d, 'persona-cuidadora', Rol.cuidador);
    final o = _srv(
      d,
      'persona-dueno',
      Rol.dueno,
      alConfirmar: (g, {libroCompartidoId}) async => llamadas.add(g),
    );
    await c.registrarGasto(concepto: 'Pañales', centavos: 18550);
    await c.registrarGasto(concepto: 'Gasas', centavos: 9000);
    final ids = [for (final g in await c.gastos()) g.id];
    expect(await o.resolverGasto(ids[0], confirmar: true), isNull);
    expect(await o.resolverGasto(ids[1], confirmar: false), isNull);
    expect(llamadas, hasLength(1));
    expect(llamadas.single.estado, EstadoGasto.confirmado);
    expect(llamadas.single.centavos, 18550);
  });

  test('si Finanzas falla, avisa y la confirmación se queda', () async {
    final d = datosDeEjemploCuidados(_ahora);
    final c = _srv(d, 'persona-cuidadora', Rol.cuidador);
    final o = _srv(
      d,
      'persona-dueno',
      Rol.dueno,
      alConfirmar: (_, {libroCompartidoId}) async =>
          throw StateError('sin permiso'),
    );
    await c.registrarGasto(concepto: 'Pañales', centavos: 18550);
    final id = (await c.gastos()).single.id;
    expect(await o.resolverGasto(id, confirmar: true), avisoGastoSinFinanzas);
    expect((await c.gastos()).single.estado, EstadoGasto.confirmado);
  });

  test('con el repositorio de Finanzas: un movimiento, sin duplicar', () async {
    final d = datosDeEjemploCuidados(_ahora);
    final base = datosDeDemostracion(hoy: hoyDePrueba);
    final salud = base.categorias.firstWhere((x) => x.nombre == 'Salud');
    final fin = RepositorioFinanzasEnMemoria(
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
    final o = _srv(
      d,
      'persona-dueno',
      Rol.dueno,
      alConfirmar: (g, {libroCompartidoId}) =>
          pasarGastoAFinanzas(fin, g, confirmadoPor: IdsDemostracion.dueno),
    );
    await o.registrarGasto(concepto: 'Pañales', centavos: 18550);
    final mio = (await o.gastos()).firstWhere((g) => g.concepto == 'Pañales');
    final id = mio.id;
    final antes = fin.actual.datos.movimientos.length;
    expect(await o.resolverGasto(id, confirmar: true), isNull);
    expect(fin.actual.datos.movimientos.length, antes + 1);
    // El mismo gasto otra vez: Finanzas no duplica.
    await pasarGastoAFinanzas(
      fin,
      mio.conEstado(EstadoGasto.confirmado),
      confirmadoPor: IdsDemostracion.dueno,
    );
    expect(fin.actual.datos.movimientos.length, antes + 1);
  });

  test('permisos: casa solo para dueño y hermana', () async {
    final d = datosDeEjemploCuidados(_ahora);
    const cuid = PermisosCuidados(rol: Rol.cuidador);
    const her = PermisosCuidados(rol: Rol.cuidador, perfil: _perfilHermana);
    const due = PermisosCuidados(rol: Rol.dueno);
    expect(cuid.registraGastoCasa, isFalse);
    expect(her.registraGastoCasa && due.registraGastoCasa, isTrue);
    final c = _srv(d, 'persona-cuidadora', Rol.cuidador);
    expect(
      () => c.registrarGasto(
        concepto: 'Luz',
        centavos: 100,
        ambito: AmbitoGasto.casa,
      ),
      throwsA(isA<ErrorCuidados>()),
    );
    final o = _srv(d, 'persona-dueno', Rol.dueno);
    await o.registrarGasto(
      concepto: 'Luz',
      centavos: 100,
      ambito: AmbitoGasto.casa,
    );
    expect(
      (await o.gastos()).firstWhere((g) => g.concepto == 'Luz').ambito,
      AmbitoGasto.casa,
    );
  });

  Future<void> abrirHoja(
    WidgetTester t,
    String id,
    Rol rol,
    PerfilCuidados perfil,
    DatosCuidadosMemoria d,
  ) async {
    await t.binding.setSurfaceSize(const Size(400, 3000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(_app(d, id, rol, perfil));
    await t.pumpAndSettle();
    await t.tap(find.text('Gastos'));
    await t.pumpAndSettle();
    await t.tap(find.text('Registrar gasto'));
    await t.pumpAndSettle();
  }

  testWidgets('la cuidadora no ve el selector', (t) async {
    await abrirHoja(
      t,
      'persona-cuidadora',
      Rol.cuidador,
      const PerfilCuidados(),
      datosDeEjemploCuidados(_ahora),
    );
    expect(find.byKey(const Key('ambito-gasto')), findsNothing);
  });

  testWidgets('la hermana elige casa y se guarda con ámbito casa', (t) async {
    final d = datosDeEjemploCuidados(_ahora);
    await abrirHoja(t, 'persona-hermana', Rol.cuidador, _perfilHermana, d);
    expect(find.text('Cuidado de Papá'), findsOneWidget);
    expect(find.text('Gastos de la casa'), findsOneWidget);
    await t.tap(find.text('Gastos de la casa'));
    await t.pump();
    await t.enterText(
      find.widgetWithText(TextField, '¿En qué se gastó?'),
      'Luz',
    );
    await t.enterText(find.widgetWithText(TextField, 'Monto en pesos'), '120');
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();
    expect(d.gastos.last.ambito, AmbitoGasto.casa);
  });

  testWidgets('por omisión es cuidado; el dueño ve los dos', (t) async {
    final d = datosDeEjemploCuidados(_ahora);
    await abrirHoja(t, 'persona-dueno', Rol.dueno, const PerfilCuidados(), d);
    expect(find.text('Gastos de la casa'), findsOneWidget);
    await t.enterText(
      find.widgetWithText(TextField, '¿En qué se gastó?'),
      'Gasas',
    );
    await t.enterText(find.widgetWithText(TextField, 'Monto en pesos'), '50');
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();
    expect(d.gastos.last.ambito, AmbitoGasto.cuidado);
  });
}
