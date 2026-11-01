// Revisión de calidad de la Fase 3: letra al 200 % (criterio 57) en las
// pantallas de Hábitos, a 360 dp (teléfono) y a 900 dp (laptop). Sin
// desbordes, y cada botón o fila que se toca mide al menos 48 dp de alto.
// F3-11 (hallazgo, menor): la lista de Objetivos pinta siempre avance 0 %.
// F3-12 (hallazgo, importante): la fila de Hoy anuncia solo el título: ni estado
//       (pendiente, hecho…) ni casilla marcada para el lector de pantalla.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/habitos/casos_uso/servicio_habitos.dart';
import 'package:gravity/modulos/habitos/datos/modelos.dart';
import 'package:gravity/modulos/habitos/datos/repositorio.dart';
import 'package:gravity/modulos/habitos/estado/proveedores.dart';
import 'package:gravity/modulos/habitos/pantallas/hoy.dart';
import 'package:gravity/modulos/habitos/pantallas/objetivos.dart';
import 'package:gravity/nucleo/sesion/proveedores_sesion.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_falso.dart';
import 'package:habitos_dominio/habitos_dominio.dart';

Future<void> montar(WidgetTester t, Widget pantalla, Size tam, RepositorioHabitosEnMemoria repo) async {
  t.view.physicalSize = tam;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [
      servicioSesionProvider.overrideWithValue(ServicioSesionFalso()),
      repositorioHabitosProvider.overrideWithValue(repo),
      servicioHabitosProvider.overrideWithValue(ServicioHabitos(repo)),
    ],
    child: MaterialApp(
      builder: (c, h) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(2.0)),
        child: h!,
      ),
      home: pantalla,
    ),
  ));
  await t.pumpAndSettle();
}

Future<RepositorioHabitosEnMemoria> repoConDatos() async {
  final repo = RepositorioHabitosEnMemoria();
  final hoy = DateTime.now();
  for (var i = 0; i < 4; i++) {
    await repo.guardarObjetivo(ObjetivoHab(
      id: 'o$i',
      titulo: 'Leer un capítulo completo de la Biblia cada mañana antes del desayuno $i',
      area: 'espiritual',
      tipo: TipoObjetivo.construir,
      fechaInicio: DateTime(hoy.year, hoy.month, hoy.day - 5),
      unidad: 'capítulos',
      metaValor: 3,
      modificadoEn: hoy,
    ));
  }
  return repo;
}

void main() {
  for (final tam in [const Size(360, 800), const Size(900, 700)]) {
    testWidgets('Hoy a 200 % en ${tam.width.toInt()} dp: sin desbordes ni toques de menos de 48 dp', (t) async {
      await montar(t, const PantallaHoyHabitos(), tam, await repoConDatos());
      expect(t.takeException(), isNull);
      for (final tipo in [FilledButton, OutlinedButton, TextButton, IconButton, FloatingActionButton, Checkbox, InkWell]) {
        for (final e in t.widgetList(find.byType(tipo)).toList().asMap().entries) {
          final r = t.getRect(find.byType(tipo).at(e.key));
          if (r.height < 47.5 && r.width > 0 && tipo != InkWell) {
            fail('$tipo ${e.key} mide ${r.height} dp de alto');
          }
        }
      }
    });

    testWidgets('Objetivos a 200 % en ${tam.width.toInt()} dp: sin desbordes', (t) async {
      await montar(t, const PantallaObjetivos(), tam, await repoConDatos());
      expect(t.takeException(), isNull);
      expect(find.textContaining('Leer un capítulo'), findsWidgets);
    });
  }

  testWidgets('F3-12: cada fila de Hoy anuncia su estado al lector de pantalla', (t) async {
    final h = t.ensureSemantics();
    await montar(t, const PantallaHoyHabitos(), const Size(360, 800), await repoConDatos());
    final etiquetas = <String>[];
    void visitar(SemanticsNode n) {
      if (n.label.contains('Leer un capítulo') && !n.label.contains('SIGUE')) etiquetas.add(n.label);
      n.visitChildren((c) {
        visitar(c);
        return true;
      });
    }
    visitar(t.getSemantics(find.byType(PantallaHoyHabitos)));
    expect(etiquetas, isNotEmpty);
    for (final e in etiquetas) {
      expect(RegExp('pendiente|hecho|parcial|omitido|pospuesto', caseSensitive: false).hasMatch(e), isTrue, reason: 'etiqueta sin estado: "$e"');
    }
    h.dispose();
  }, tags: 'hallazgo');

  testWidgets('F3-11: la lista de Objetivos no pinta 0 % de avance a quien ya cumplió', (t) async {
    final repo = await repoConDatos();
    final hoy = DateTime.now();
    for (var d = 0; d < 3; d++) {
      await repo.guardarRegistro(RegistroHab(
        id: 'r$d',
        objetivoId: 'o0',
        fecha: DateTime(hoy.year, hoy.month, hoy.day - d),
        estado: EstadoRegistro.hecho,
        valor: 3,
        modificadoEn: hoy,
      ));
    }
    await montar(t, const PantallaObjetivos(), const Size(360, 800), repo);
    expect(find.textContaining('0 %'), findsNothing, reason: 'todas las tarjetas dicen 0 %');
  }, tags: 'hallazgo');
}
