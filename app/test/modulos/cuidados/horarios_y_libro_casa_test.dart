// Fase 5 (8h): horarios de comida editables por el dueño y libro compartido
// elegido al confirmar un gasto de la casa.
import 'package:finanzas_dominio/finanzas_dominio.dart';
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
import 'package:gravity/modulos/cuidados/pantallas/comidas.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart'
    show repositorioFinanzasProvider;
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/seguridad/almacen_seguro.dart';
import 'package:gravity/nucleo/seguridad/proveedores_seguridad.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:gravity/nucleo/sesion/sesion.dart';

import '../finanzas/ayuda_finanzas.dart';

final _ahora = DateTime(2026, 11, 4, 10);

Widget _app(
  Widget pantalla,
  DatosCuidadosMemoria d,
  String id,
  Rol rol, {
  PerfilCuidados perfil = const PerfilCuidados(),
  RepositorioFinanzasEnMemoria? fin,
}) => ProviderScope(
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
    if (fin != null) repositorioFinanzasProvider.overrideWithValue(fin),
  ],
  child: MaterialApp(home: pantalla),
);

ServicioCuidados _srv(DatosCuidadosMemoria d, String id, Rol rol) =>
    ServicioCuidados(
      RepositorioCuidadosEnMemoria(datos: d, personaId: id, rol: rol),
      permisos: PermisosCuidados(rol: rol),
      personaId: id,
      nombre: id,
      ahora: () => _ahora,
    );

void main() {
  group('horarios de comida', () {
    test('por omisión son 8:30, 14:00, 17:00 y 19:00', () async {
      final h = await _srv(
        datosDeEjemploCuidados(_ahora),
        'persona-dueno',
        Rol.dueno,
      ).horariosComida();
      expect(h[TiempoComidaPapa.desayuno], const HoraComida(8, 30));
      expect(h[TiempoComidaPapa.comida], const HoraComida(14));
      expect(h[TiempoComidaPapa.colacion], const HoraComida(17));
      expect(h[TiempoComidaPapa.cena], const HoraComida(19));
    });

    test(
      'el dueño los cambia y los demás los ven; los demás no editan',
      () async {
        final d = datosDeEjemploCuidados(_ahora);
        final dueno = _srv(d, 'persona-dueno', Rol.dueno);
        await dueno.fijarHorarioComida(
          TiempoComidaPapa.comida,
          const HoraComida(13, 15),
        );
        final cuidadora = _srv(d, personasDemo.cuidadoraId, Rol.cuidador);
        expect(
          (await cuidadora.horariosComida())[TiempoComidaPapa.comida],
          const HoraComida(13, 15),
        );
        expect(
          () => cuidadora.fijarHorarioComida(
            TiempoComidaPapa.comida,
            const HoraComida(9),
          ),
          throwsA(isA<ErrorCuidados>()),
        );
      },
    );

    test('solo el dueño (no la maestra) tiene el permiso de editar', () {
      const hermana = PerfilCuidados(esFamiliar: true);
      expect(
        const PermisosCuidados(rol: Rol.dueno).editaHorariosComida,
        isTrue,
      );
      expect(
        const PermisosCuidados(rol: Rol.cuidador).editaHorariosComida,
        isFalse,
      );
      expect(
        const PermisosCuidados(
          rol: Rol.cuidador,
          perfil: hermana,
        ).editaHorariosComida,
        isFalse,
      );
      expect(
        const PermisosCuidados(rol: Rol.coadministrador).editaHorariosComida,
        isFalse,
      );
      expect(
        const PermisosCuidados(
          rol: Rol.dueno,
          esMaestra: true,
        ).editaHorariosComida,
        isFalse,
      );
    });

    testWidgets('el dueño ve el botón; la cuidadora ve la hora sin botón', (
      t,
    ) async {
      await t.binding.setSurfaceSize(const Size(400, 3000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final d = datosDeEjemploCuidados(_ahora);
      await t.pumpWidget(
        _app(const PantallaComidas(), d, 'persona-dueno', Rol.dueno),
      );
      await t.pumpAndSettle();
      expect(find.text('Comida: 14:00'), findsOneWidget);
      expect(find.byKey(const Key('editar-horario-comida')), findsOneWidget);

      await t.pumpWidget(
        _app(
          const PantallaComidas(),
          d,
          personasDemo.cuidadoraId,
          Rol.cuidador,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Comida: 14:00'), findsOneWidget);
      expect(find.byKey(const Key('editar-horario-comida')), findsNothing);
    });
  });

  group('libro de la casa al confirmar', () {
    Future<({DatosCuidadosMemoria d, RepositorioFinanzasEnMemoria fin})>
    preparar({bool dosLibros = false}) async {
      final d = datosDeEjemploCuidados(_ahora);
      var base = datosDeDemostracion(hoy: hoyDePrueba);
      if (dosLibros) {
        base = base.copiar(
          libros: [
            ...base.libros,
            Libro(
              id: 'libro-viajes',
              nombre: 'Viajes',
              tipo: TipoLibro.compartido,
              creadoPor: IdsDemostracion.dueno,
              miembros: [
                MiembroLibro(
                  personaId: IdsDemostracion.dueno,
                  papel: PapelLibro.miembro,
                ),
              ],
            ),
          ],
        );
      }
      final fin = RepositorioFinanzasEnMemoria(
        datos: base,
        personaId: IdsDemostracion.dueno,
        reloj: () => ahoraDePrueba,
      );
      await _srv(d, IdsDemostracion.dueno, Rol.dueno).registrarGasto(
        concepto: 'Luz',
        centavos: 45000,
        ambito: AmbitoGasto.casa,
      );
      return (d: d, fin: fin);
    }

    Future<void> abrir(
      WidgetTester t,
      DatosCuidadosMemoria d,
      RepositorioFinanzasEnMemoria fin,
    ) async {
      await t.binding.setSurfaceSize(const Size(400, 3000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        _app(
          const PantallaBitacora(),
          d,
          IdsDemostracion.dueno,
          Rol.dueno,
          fin: fin,
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Gastos'));
      await t.pumpAndSettle();
    }

    int enLibro(RepositorioFinanzasEnMemoria r, String libro) {
      final x = r.actual.datos;
      return x.movimientos
          .where((m) => x.cuenta(m.cuentaOrigenId)?.libroId == libro)
          .length;
    }

    test('el servicio exige libro para un gasto de la casa', () async {
      final d = datosDeEjemploCuidados(_ahora);
      final llamadas = <String?>[];
      final o = ServicioCuidados(
        RepositorioCuidadosEnMemoria(
          datos: d,
          personaId: 'persona-dueno',
          rol: Rol.dueno,
        ),
        permisos: const PermisosCuidados(rol: Rol.dueno),
        personaId: 'persona-dueno',
        nombre: 'Dueño',
        ahora: () => _ahora,
        alConfirmarGasto: (g, {libroCompartidoId}) async =>
            llamadas.add(libroCompartidoId),
      );
      await o.registrarGasto(
        concepto: 'Luz',
        centavos: 100,
        ambito: AmbitoGasto.casa,
      );
      final id = (await o.gastos()).firstWhere((g) => g.concepto == 'Luz').id;
      await expectLater(
        o.resolverGasto(id, confirmar: true),
        throwsA(isA<ErrorCuidados>()),
      );
      // No quedó confirmado ni pasó a Finanzas.
      expect(
        (await o.gastos()).firstWhere((g) => g.id == id).estado,
        EstadoGasto.pendiente,
      );
      expect(llamadas, isEmpty);
      await o.resolverGasto(id, confirmar: true, libroCompartidoId: 'libro-x');
      expect(llamadas, ['libro-x']);
    });

    testWidgets(
      'un solo libro: viene elegido, se confirma y llega a Finanzas',
      (t) async {
        final p = await preparar();
        await abrir(t, p.d, p.fin);
        final antes = enLibro(p.fin, IdsDemostracion.libroCasa);
        await t.tap(find.text('Confirmar'));
        await t.pumpAndSettle();
        expect(find.text('¿En qué libro va este gasto?'), findsOneWidget);
        final boton = t.widget<FilledButton>(
          find.byKey(const Key('confirmar-libro')),
        );
        expect(boton.onPressed, isNotNull);
        await t.tap(find.byKey(const Key('confirmar-libro')));
        await t.pumpAndSettle();
        expect(enLibro(p.fin, IdsDemostracion.libroCasa), antes + 1);
      },
    );

    testWidgets('con dos libros exige elegir y el elegido recibe el gasto', (
      t,
    ) async {
      final p = await preparar(dosLibros: true);
      await abrir(t, p.d, p.fin);
      final antes = p.fin.actual.datos.movimientos.length;
      await t.tap(find.text('Confirmar'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<FilledButton>(find.byKey(const Key('confirmar-libro')))
            .onPressed,
        isNull,
      );
      expect(p.fin.actual.datos.movimientos.length, antes);
      await t.tap(find.byKey(const Key('libro-${IdsDemostracion.libroCasa}')));
      await t.pump();
      await t.tap(find.byKey(const Key('confirmar-libro')));
      await t.pumpAndSettle();
      expect(p.fin.actual.datos.movimientos.length, antes + 1);
      expect(enLibro(p.fin, IdsDemostracion.libroCasa), greaterThan(0));
    });

    testWidgets('el gasto de Papá se confirma sin elegir libro', (t) async {
      final d = datosDeEjemploCuidados(_ahora);
      final fin = RepositorioFinanzasEnMemoria(
        datos: datosDeDemostracion(hoy: hoyDePrueba),
        personaId: IdsDemostracion.dueno,
        reloj: () => ahoraDePrueba,
      );
      await _srv(
        d,
        IdsDemostracion.dueno,
        Rol.dueno,
      ).registrarGasto(concepto: 'Pañales', centavos: 18550);
      await abrir(t, d, fin);
      await t.tap(find.text('Confirmar'));
      await t.pumpAndSettle();
      expect(find.text('¿En qué libro va este gasto?'), findsNothing);
      expect(enLibro(fin, IdsDemostracion.libroPapa), greaterThan(0));
    });
  });
}
