// G6-M3 · El aviso del banco (spec 3.2): antes de la PRIMERA vez que una sesión
// usa el banco (fondos, subidas, sentadilla al banco, puente apoyado) se pide
// comprobar en el aparato su capacidad y su estabilidad, y la persona lo
// confirma con «Ya lo revisé». Una sola vez por persona, solo en este equipo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/gimnasio/acceso_gimnasio.dart';
import 'package:gravity/modulos/habitos/gimnasio/casos_uso/aviso_banco.dart';
import 'package:gravity/modulos/habitos/gimnasio/casos_uso/modo_foco.dart';
import 'package:gravity/modulos/habitos/gimnasio/pantallas/comun.dart';
import 'package:habitos_dominio/habitos_dominio.dart' hide EstadoDiaPlan;

import 'ayuda_gimnasio_app.dart';

const alto = Size(400, 3200);

void main() {
  late Mundo m;
  setUp(() => m = Mundo());
  tearDown(() => m.cerrar());

  final aviso = find.byKey(const ValueKey('aviso-banco'));
  final reviso = find.byKey(const ValueKey('aviso-banco-revise'));

  group('qué sesiones usan el banco', () {
    test('A (fondos) y C (subidas, sentadilla, puente) sí; B no', () async {
      final c = catalogoGimnasio;
      Future<bool> usa(DateTime dia) async {
        final h = await m.servicio.entrenamientoDe(dia);
        return sesionUsaBanco(h.sesion!, c);
      }

      expect(await usa(lunes30), isTrue); // A
      expect(await usa(DateTime(2026, 12, 1)), isTrue); // C
      expect(await usa(DateTime(2026, 12, 2)), isFalse); // B
    });

    test('el texto pide la capacidad y la estabilidad, sin diagnosticar', () {
      final t = TextosHabitosGimnasio.avisoBanco.toLowerCase();
      expect(t, contains('banco'));
      expect(t, contains('capacidad'));
      expect(t, contains('estable'));
      expect(t, isNot(contains('!')));
      expect(palabrasMedicasEn(TextosHabitosGimnasio.avisoBanco), isEmpty);
    });
  });

  group('AvisoBancoLocal', () {
    test('una sola vez por persona, y solo en este equipo', () async {
      final a = AvisoBancoLocal(m.almacen, persona);
      final otra = AvisoBancoLocal(m.almacen, 'uid-alex');
      expect(await a.revisado(), isFalse);
      await a.marcarRevisado(DateTime(2026, 11, 30, 19));
      expect(await a.revisado(), isTrue);
      expect(await otra.revisado(), isFalse);
      // Una lectura rota del almacén no lo marca como revisado ni lanza.
      await m.almacen.escribir('habitos.copia.$persona', 'no es json');
      expect(await a.revisado(), isFalse);
    });

    test('convive con la copia del modo foco sin pisarla', () async {
      final copia = CopiaLocalFoco(m.almacen, persona);
      await copia.registrar(
        claveAnonimaDeFoco,
        diaD: DateTime(2026, 11, 30),
        focoDias: 3,
      );
      final a = AvisoBancoLocal(m.almacen, persona);
      await a.marcarRevisado(DateTime(2026, 11, 30));
      expect((await copia.leer())!.para(DateTime(2026, 12, 1)), isTrue);
      expect(await a.revisado(), isTrue);
      // Y al revés: anotar un foco después no borra que ya lo revisó.
      await copia.registrar(
        claveAnonimaDeFoco,
        diaD: DateTime(2026, 12, 7),
        focoDias: 3,
      );
      expect(await a.revisado(), isTrue);
    });
  });

  group('E4 · Sesión de hoy', () {
    testWidgets('sale antes de la primera vez, se confirma y no vuelve', (
      t,
    ) async {
      await montarPantalla(t, m, DestinoGimnasio.sesion, tamano: alto);
      expect(aviso, findsOneWidget);
      expect(find.text(TextosHabitosGimnasio.avisoBanco), findsOneWidget);
      expect(find.text(TextosHabitosGimnasio.yaLoRevise), findsOneWidget);
      // No impide empezar (sin culpa): el botón sigue ahí.
      expect(find.byKey(const ValueKey('sesion-empezar')), findsOneWidget);

      await t.tap(reviso);
      await t.pumpAndSettle();
      expect(aviso, findsNothing);
      expect(await AvisoBancoLocal(m.almacen, persona).revisado(), isTrue);

      // Otra vez a la pantalla (otro montaje, mismo equipo): no vuelve a salir.
      await montarPantalla(t, m, DestinoGimnasio.sesion, tamano: alto);
      expect(aviso, findsNothing);
    });

    testWidgets('una sesión sin banco (B) no lo muestra', (t) async {
      m.ahoraActual = DateTime(2026, 12, 2, 19);
      await montarPantalla(t, m, DestinoGimnasio.sesion, tamano: alto);
      expect(aviso, findsNothing);
      expect(await AvisoBancoLocal(m.almacen, persona).revisado(), isFalse);
    });

    testWidgets('la regenerativa no lo muestra', (t) async {
      await montarPantalla(t, m, DestinoGimnasio.sesion, tamano: alto);
      expect(aviso, findsOneWidget);
      await t.tap(find.text(TextosHabitosGimnasio.cansado));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('ver-regenerativa')));
      await t.pumpAndSettle();
      expect(aviso, findsNothing);
    });
  });

  group('E5 · Sesión en curso', () {
    testWidgets('sale en el calentamiento, antes de la primera serie', (
      t,
    ) async {
      await montarPantalla(t, m, DestinoGimnasio.sesionEnCurso, tamano: alto);
      expect(aviso, findsOneWidget);
      await t.tap(reviso);
      await t.pumpAndSettle();
      expect(aviso, findsNothing);
      // La sesión sigue su curso.
      expect(find.byKey(const ValueKey('calentamiento-listo')), findsOneWidget);
    });
  });
}
