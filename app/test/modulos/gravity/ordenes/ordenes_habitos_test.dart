// Criterios 53 y 54 de la Fase 3 (docs/specs/fase-3-habitos.md): las órdenes de
// Hábitos y su historial. Las que mencionan un hábito sensible o el diario
// nunca se guardan tal cual: queda "Orden de Hábitos reservada".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/pantallas_externas.dart'
    show consultaLocalHabitosProvider;
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/modulos/gravity/ordenes/barra_ordenes.dart';
import 'package:gravity/modulos/gravity/ordenes/interprete_ordenes.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/herramientas/herramientas.dart';

void main() {
  const ordenes = {
    'abre hoy': 'habitos.abrir_hoy',
    'mi agenda': 'habitos.abrir_agenda',
    'abre espiritual': 'habitos.abrir_espiritual',
    'abre el lector': 'habitos.abrir_lector',
    'abre mi revisión': 'habitos.abrir_revision',
    'pausa': 'habitos.abrir_pausa',
    'tengo un antojo': 'habitos.sos',
    'resumen de hoy': 'habitos.resumen_hoy',
  };

  group('53: las órdenes llevan a su herramienta', () {
    for (final rol in [Rol.dueno, Rol.coadministrador, Rol.familiar]) {
      test('${rol.name}: cada frase abre su vista', () {
        final interprete = InterpreteOrdenes(
          rol: rol,
          dispositivo: TipoDispositivo.telefono,
        );
        for (final MapEntry(key: orden, value: nombre) in ordenes.entries) {
          expect(
            switch (interprete.interpretar(orden)) {
              OrdenEntendida(:final destino) => destino.nombre,
              _ => null,
            },
            nombre,
            reason: orden,
          );
        }
      });
    }

    test('las nueve de Hábitos son solo locales, de solo abrir o consultar y '
        'ninguna escribe', () {
      final registro = registroDeGravity();
      final deHabitos = registro.todas.where((h) => h.modulo == Modulo.habitos);
      expect(deHabitos.map((h) => h.nombre).toSet(), {
        'habitos.abrir',
        ...ordenes.values,
      });
      for (final h in deHabitos) {
        expect(h.soloLocal, isTrue, reason: h.nombre);
        expect(h.escribe, isFalse, reason: h.nombre);
        expect(h.accion, Accion.leer, reason: h.nombre);
        expect(h.guardaEnHistorial, isFalse, reason: h.nombre);
      }
    });

    test('cuidador, Casa y la maestra que no es dueña no las reciben', () {
      for (final (rol, maestra) in [
        (Rol.cuidador, false),
        (Rol.casa, false),
        (Rol.coadministrador, true),
      ]) {
        final interprete = InterpreteOrdenes(
          rol: rol,
          dispositivo: TipoDispositivo.telefono,
          esMaestra: maestra,
        );
        for (final orden in ordenes.keys) {
          expect(
            interprete.interpretar(orden),
            isNot(isA<OrdenEntendida>()),
            reason: '$orden / ${rol.name}',
          );
        }
        expect(
          interprete.destinos.where((d) => d.modulo == Modulo.habitos),
          isEmpty,
        );
      }
    });

    test(
      'el resumen de hoy entrega el texto local, sin nada para la IA',
      () async {
        final registro = registroDeGravity();
        final r = await registro.ejecutar(
          'habitos.resumen_hoy',
          const {},
          ContextoHerramienta(
            rol: Rol.familiar,
            navegar: (_) {},
            consultaLocal: (n) async =>
                n == 'habitos.resumen_hoy' ? 'Hoy llevas 3 de 5.' : null,
          ),
        );
        expect(r.contenido, 'Hoy llevas 3 de 5.');
        expect(r.paraIa, isNull);
        expect(r.soloLocal, isTrue);
        // Sin proveedor, solo abre la vista.
        final rutas = <String>[];
        final sin = await registro.ejecutar(
          'habitos.resumen_hoy',
          const {},
          ContextoHerramienta(rol: Rol.familiar, navegar: rutas.add),
        );
        expect(rutas, [RutasDeHerramientas.hoyHabitos]);
        expect(sin.paraIa, isNull);
      },
    );

    test(
      'el proveedor de la plataforma solo contesta a habitos.resumen_hoy',
      () async {
        final c = ProviderContainer();
        addTearDown(c.dispose);
        final consulta = c.read(consultaLocalHabitosProvider);
        expect(await consulta('finanzas.resumen_semana'), isNull);
        expect(await consulta('habitos.abrir_hoy'), isNull);
      },
    );
  });

  group('54: el historial guarda "Orden de Hábitos reservada"', () {
    final interprete = InterpreteOrdenes(
      rol: Rol.familiar,
      dispositivo: TipoDispositivo.telefono,
    );

    test('lo que menciona un hábito sensible o el diario nunca se guarda tal '
        'cual', () {
      for (final orden in [
        'tengo un antojo de cigarro',
        'registra mi consumo de azúcar',
        'abre mi diario',
        'abre mi oración',
        'abre el devocional',
        'pausa',
        'quiero eliminar el tabaco',
        'SOS',
      ]) {
        expect(
          interprete.paraHistorial(orden),
          ordenDeHabitosReservada,
          reason: orden,
        );
        expect(
          textoParaHistorial(orden),
          ordenDeHabitosReservada,
          reason: orden,
        );
      }
    });

    test('toda orden que lleva a Hábitos se reserva, aunque sea ambigua', () {
      for (final orden in ordenes.keys) {
        expect(
          interprete.paraHistorial(orden),
          ordenDeHabitosReservada,
          reason: orden,
        );
      }
      // Una a medias que podría llevar a Hábitos también.
      expect(interprete.paraHistorial('abre hab'), ordenDeHabitosReservada);
    });

    test('las demás órdenes se guardan igual', () {
      for (final orden in ['abre presupuesto', 'abre casa', 'ajustes']) {
        expect(
          InterpreteOrdenes(rol: Rol.dueno).paraHistorial(orden),
          orden,
          reason: orden,
        );
      }
    });

    test('quien no tiene Hábitos no lo delata: su orden de Hábitos tampoco se '
        'guarda', () {
      final cuidador = InterpreteOrdenes(rol: Rol.cuidador);
      expect(
        cuidador.paraHistorial('tengo un antojo'),
        ordenDeHabitosReservada,
      );
      expect(cuidador.paraHistorial('abre hoy'), 'abre hoy');
    });

    testWidgets(
      'la barra no escribe lo que se pidió en ningún lado: tras abrir '
      'queda vacía',
      (tester) async {
        final rutas = <String>[];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [esCuentaMaestraProvider.overrideWithValue(false)],
            child: MaterialApp(
              home: Scaffold(
                body: BarraOrdenes(
                  rol: Rol.familiar,
                  dispositivo: TipoDispositivo.telefono,
                  onNavegar: rutas.add,
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'tengo un antojo');
        await tester.testTextInput.receiveAction(TextInputAction.go);
        await tester.pumpAndSettle();
        expect(rutas, ['/habitos/sos']);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
      },
    );
  });
}
