// D24: cómo se llega a la vista temporal. El familiar abre solo la pantalla de
// pedir (excepción estrecha del router); la tarjeta de autorizar es del dueño.
import 'package:finanzas_dominio/finanzas_dominio.dart' show Fecha;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/navegacion.dart';
import 'package:gravity/modulos/finanzas/datos/demostracion.dart';
import 'package:gravity/modulos/finanzas/datos/vista_papa.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores_vista_papa.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';

import 'ayuda_plataforma.dart';

void main() {
  group('guardia de rutas (función pura)', () {
    String? ir(String ruta, Rol rol) => calcularRedireccion(
      ubicacion: ruta,
      rol: rol,
      dispositivo: TipoDispositivo.telefono,
    );

    test('el familiar abre solo la pantalla de pedir', () {
      expect(ir(RutasApp.vistaPapa, Rol.familiar), isNull);
      // Ningún otro camino de Finanzas se abre.
      for (final ruta in [
        Rutas.finanzas,
        '${Rutas.finanzas}/semana',
        '${Rutas.finanzas}/vista-papa/datos',
        '${Rutas.finanzas}/vista-papa-otra',
        '${Rutas.finanzas}/movimientos',
      ]) {
        expect(ir(ruta, Rol.familiar), Rutas.inicio, reason: ruta);
      }
    });

    test('Casa y cuidador siguen sin acceso', () {
      expect(ir(RutasApp.vistaPapa, Rol.casa), Rutas.inicio);
      expect(ir(RutasApp.vistaPapa, Rol.cuidador), Rutas.cuidados);
    });

    test('sin sesión sigue llevando a Entrar', () {
      expect(ir(RutasApp.vistaPapa, Rol.familiar), isNull);
      expect(
        calcularRedireccion(
          ubicacion: RutasApp.vistaPapa,
          rol: null,
          dispositivo: TipoDispositivo.telefono,
        ),
        Rutas.entrar,
      );
    });
  });

  group('en la app', () {
    final inicio = DateTime(2026, 11, 6, 10);
    final duenoId = IdsDemostracion.dueno;
    final familiarId = personasDeEjemplo[Rol.familiar]!.id;

    RepositorioVistaPapaEnMemoria servidor() => RepositorioVistaPapaEnMemoria(
      personaId: duenoId,
      duenoId: duenoId,
      reloj: () => inicio,
      datosPapa: datosDeLibros(
        datosDeDemostracion(hoy: Fecha.deDateTime(inicio)),
        {IdsDemostracion.libroPapa},
        conservarLibros: false,
      ),
    );

    testWidgets('el familiar llega a la pantalla de pedir desde Más', (
      t,
    ) async {
      final s = servidor();
      await montarApp(
        t,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.familiar),
        extras: [
          repositorioVistaPapaProvider.overrideWithValue(
            s.comoPersona(familiarId),
          ),
        ],
      );
      // No está en Hoy ni en las pestañas.
      expect(find.text('Pedir ver finanzas de Papá'), findsNothing);
      await t.tap(find.text('Más'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('acceso-pedir-vista-papa')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('vista-papa-motivo')), findsOneWidget);
      // Sin autorización no hay datos ni contador.
      expect(find.byKey(const ValueKey('vista-papa-contador')), findsNothing);
    });

    testWidgets('el familiar en la laptop tiene el acceso al pie de GRAVITY', (
      t,
    ) async {
      final s = servidor();
      await montarApp(
        t,
        dispositivo: TipoDispositivo.laptop,
        sesion: sesionCon(Rol.familiar),
        extras: [
          repositorioVistaPapaProvider.overrideWithValue(
            s.comoPersona(familiarId),
          ),
        ],
      );
      await t.tap(find.byKey(const ValueKey('acceso-pedir-vista-papa')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('vista-papa-motivo')), findsOneWidget);
    });

    for (final rol in [Rol.dueno, Rol.coadministrador, Rol.casa]) {
      testWidgets('${rol.name} no ve el acceso del familiar en Más', (t) async {
        final s = servidor();
        await montarApp(
          t,
          dispositivo: TipoDispositivo.telefono,
          sesion: sesionCon(rol),
          extras: [
            repositorioVistaPapaProvider.overrideWithValue(
              s.comoPersona(duenoId),
            ),
          ],
        );
        await t.tap(find.text('Más'));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('acceso-pedir-vista-papa')),
          findsNothing,
        );
      });
    }

    testWidgets('el dueño ve la tarjeta en Hoy y el familiar no', (t) async {
      final s = servidor();
      await s.comoPersona(familiarId).pedir('Revisar los pagos de la luz');
      await montarApp(
        t,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.dueno),
        extras: [
          repositorioVistaPapaProvider.overrideWithValue(
            s.comoPersona(duenoId),
          ),
        ],
      );
      expect(
        find.byKey(const ValueKey('vista-papa-tarjeta-dueno')),
        findsOneWidget,
      );
      expect(find.textContaining(r'$'), findsNothing);
    });

    testWidgets('el familiar no ve la tarjeta del dueño', (t) async {
      final s = servidor();
      await s.comoPersona(familiarId).pedir('Revisar los pagos de la luz');
      await montarApp(
        t,
        dispositivo: TipoDispositivo.telefono,
        sesion: sesionCon(Rol.familiar),
        extras: [
          repositorioVistaPapaProvider.overrideWithValue(
            s.comoPersona(familiarId),
          ),
        ],
      );
      expect(
        find.byKey(const ValueKey('vista-papa-tarjeta-dueno')),
        findsNothing,
      );
    });
  });
}
