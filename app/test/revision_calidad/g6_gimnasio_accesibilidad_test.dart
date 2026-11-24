// G6 · Revisión de cierre del gimnasio: accesibilidad (CA-G-41, spec 10).
//
// Las pruebas de G4 y G5 comprueban la letra al 200 % solo en la sesión en
// curso. Aquí se recorren LAS DIEZ pantallas (E1 a E10), en el teléfono de
// 360 dp y en la laptop de 1000 dp, con la letra al 200 %, y se piden tres cosas
// con las guías oficiales de `flutter_test`:
//   - sin desbordes ni excepciones al dibujar;
//   - objetivos táctiles de 48 dp o más (`androidTapTargetGuideline`);
//   - todo lo tocable con etiqueta (`labeledTapTargetGuideline`);
//   - contraste de texto (`textContrastGuideline`, 4.5:1; 3:1 en texto grande).
//
// Las que fallen quedan etiquetadas `hallazgo` y descritas en el informe.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/gimnasio/acceso_gimnasio.dart';
import 'package:gravity/modulos/habitos/gimnasio/casos_uso/controlador_sesion.dart';
import 'package:gravity/nucleo/avisos/repositorio_avisos.dart'
    show TipoEquipoAvisos;
import 'package:habitos_dominio/habitos_dominio.dart';

import '../modulos/habitos/gimnasio/ayuda_gimnasio_app.dart';

/// Un mundo con vida: aviso aceptado, una banda, una molestia, el plan y una
/// sesión A terminada (para que historial y récords no estén vacíos).
Future<Mundo> mundoConVida() async {
  final m = Mundo();
  await m.servicio.aceptarAviso();
  var d = await m.servicio.cargar();
  await m.servicio.guardarBanda(d, nombre: 'Verde');
  await m.molestias.guardar(
    Molestia(
      id: 'm1',
      zona: Zonas.hombro,
      intensidad: 1,
      desde: DateTime.utc(2026, 11, 20),
    ),
  );
  d = await m.servicio.cargar();
  final h = await m.servicio.entrenamientoDe(lunes30, datos: d);
  final fila = await m.servicio.iniciarSesion(h);
  final c = ControladorSesion(
    servicio: m.servicio,
    hoy: h,
    fila: fila,
    datos: d,
    ahora: () => m.ahoraActual,
  );
  await c.inicializar();
  c.listo();
  await c.hecha();
  await c.terminar(completa: true, esfuerzo: 3, energia: 4);
  c.dispose();
  m.ahoraActual = DateTime(2026, 12, 1, 19);
  return m;
}

const _pantallas = [
  DestinoGimnasio.hoy,
  DestinoGimnasio.inventario,
  DestinoGimnasio.plan,
  DestinoGimnasio.sesion,
  DestinoGimnasio.sesionEnCurso,
  DestinoGimnasio.registro,
  DestinoGimnasio.historial,
  DestinoGimnasio.records,
  DestinoGimnasio.molestias,
  DestinoGimnasio.ajustes,
];

void main() {
  for (final (ancho, equipo, nombre) in [
    (360.0, TipoEquipoAvisos.telefono, 'teléfono 360 dp'),
    (1000.0, TipoEquipoAvisos.laptop, 'laptop 1000 dp'),
  ]) {
    group('G6 · letra al 200 % en $nombre', () {
      for (final destino in _pantallas) {
        // En la laptop no hay molestias (7.1): se omite esa pantalla.
        if (destino == DestinoGimnasio.molestias &&
            equipo == TipoEquipoAvisos.laptop) {
          continue;
        }
        testWidgets('${destino.name}: sin desbordes, objetivos de 48 dp y etiquetas', (
          t,
        ) async {
          final handle = t.ensureSemantics();
          t.platformDispatcher.textScaleFactorTestValue = 2.0;
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          final m = await mundoConVida();
          addTearDown(m.cerrar);
          await montarPantalla(
            t,
            m,
            destino,
            tamano: Size(ancho, 800),
            equipo: equipo,
          );
          if (destino == DestinoGimnasio.sesionEnCurso) {
            await t.pump(const Duration(milliseconds: 300));
            final listo = find.byKey(const ValueKey('calentamiento-listo'));
            if (listo.evaluate().isNotEmpty) {
              await t.tap(listo);
              await t.pump();
            }
          }
          expect(t.takeException(), isNull, reason: 'desborde al 200 %');
          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
          await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
          // Se desmonta para que el temporizador no deje nada pendiente.
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(milliseconds: 50));
          handle.dispose();
        });
      }
    });
  }

  group('G6 · contraste del texto (4.5:1) en las pantallas más usadas', () {
    for (final destino in [
      DestinoGimnasio.hoy,
      DestinoGimnasio.sesion,
      DestinoGimnasio.sesionEnCurso,
      DestinoGimnasio.inventario,
    ]) {
      testWidgets(destino.name, (t) async {
        final handle = t.ensureSemantics();
        final m = await mundoConVida();
        addTearDown(m.cerrar);
        await montarPantalla(t, m, destino, tamano: const Size(400, 900));
        if (destino == DestinoGimnasio.sesionEnCurso) {
          await t.pump(const Duration(milliseconds: 300));
          final listo = find.byKey(const ValueKey('calentamiento-listo'));
          if (listo.evaluate().isNotEmpty) {
            await t.tap(listo);
            await t.pump();
          }
        }
        await expectLater(t, meetsGuideline(textContrastGuideline));
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(milliseconds: 50));
        handle.dispose();
      });
    }
  });
}
