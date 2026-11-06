// Guardia de la revisión de calidad de la Fase 1 (sección 6 de la
// especificación: "todas las pantallas tienen estados vacío, cargando, sin
// conexión y error"). Ninguna prueba del repositorio miraba estos estados en
// pantalla. Hoy PASAN y deben seguir pasando.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio.dart';
import 'package:gravity/modulos/finanzas/datos/repositorio_memoria.dart';
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/contratos/rutas.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';

import '../app/ayuda_plataforma.dart';
import '../modulos/finanzas/ayuda_finanzas.dart';
import 'ayuda_calidad.dart' show irA;

/// Repositorio cuya carga la decide la prueba.
class _RepoQueCarga extends RepositorioFinanzasEnMemoria {
  _RepoQueCarga(this._cargador, {super.datos, super.personaId});

  final Future<CargaFinanzas> Function(RepositorioFinanzasEnMemoria) _cargador;

  @override
  Future<CargaFinanzas> cargar() => _cargador(this);
}

Future<void> _montar(
  WidgetTester tester,
  RepositorioFinanzas repo, {
  TipoDispositivo dispositivo = TipoDispositivo.telefono,
}) async {
  final sesion = sesionDe(Rol.dueno);
  await montarApp(
    tester,
    dispositivo: dispositivo,
    sesion: ServicioSesionDemostracion(inicial: sesion),
    extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
  );
}

void main() {
  final sesion = sesionDe(Rol.dueno);

  for (final dispositivo in [
    TipoDispositivo.telefono,
    TipoDispositivo.laptop,
  ]) {
    group('Finanzas en $dispositivo', () {
      testWidgets('cargando: muestra el indicador y su texto', (tester) async {
        final pendiente = Completer<CargaFinanzas>();
        final repo = _RepoQueCarga((_) => pendiente.future);
        addTearDown(repo.cerrar);
        // La carga no termina: no se puede esperar a que se asiente.
        final base = repositorioDe(sesion);
        addTearDown(base.cerrar);
        await montarApp(
          tester,
          dispositivo: dispositivo,
          sesion: ServicioSesionDemostracion(inicial: sesion),
          extras: [repositorioFinanzasProvider.overrideWithValue(repo)],
        );
        // El router abre el inicio del módulo; si ya está en él, no hace falta.
        await tester.pump(const Duration(milliseconds: 200));
        await irA(tester, Rutas.finanzas);
        expect(find.text('Cargando Finanzas…'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsWidgets);
      });

      testWidgets('sin conexión y sin copia: lo dice y ofrece Reintentar', (
        tester,
      ) async {
        final repo = _RepoQueCarga((_) async => throw ErrorFinanzas.conexion);
        addTearDown(repo.cerrar);
        await _montar(tester, repo, dispositivo: dispositivo);
        await irA(tester, Rutas.finanzas);
        // Riverpod reintenta solo una carga fallida (11 veces, ~40 s) y mientras
        // tanto muestra "Cargando": ver f1_i10_error_sin_reintentos_automaticos_test.
        await tester.pump(const Duration(seconds: 60));
        expect(
          find.byKey(const ValueKey('finanzas-sin-conexion')),
          findsOneWidget,
        );
        expect(
          find.text('Sin conexión y sin datos guardados en este equipo.'),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsOneWidget);
      });

      testWidgets('error del servidor: muestra el mensaje y Reintentar', (
        tester,
      ) async {
        final repo = _RepoQueCarga(
          (_) async => throw const ErrorFinanzas('Falla de prueba'),
        );
        addTearDown(repo.cerrar);
        await _montar(tester, repo, dispositivo: dispositivo);
        await irA(tester, Rutas.finanzas);
        await tester.pump(
          const Duration(seconds: 60),
        ); // ver el comentario de arriba
        expect(find.byKey(const ValueKey('finanzas-error')), findsOneWidget);
        expect(find.text('No se pudo cargar Finanzas.'), findsOneWidget);
        expect(find.text('Falla de prueba'), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);
      });

      testWidgets('sin libros: estado vacío con su explicación', (
        tester,
      ) async {
        final repo = RepositorioFinanzasEnMemoria(personaId: sesion.persona.id);
        addTearDown(repo.cerrar);
        await _montar(tester, repo, dispositivo: dispositivo);
        await irA(tester, Rutas.finanzas);
        expect(
          find.text('Aún no tienes un libro de Finanzas.'),
          findsOneWidget,
        );
      });

      testWidgets('con lo último cargado y sin señal: aviso y lo guardado', (
        tester,
      ) async {
        final base = repositorioDe(sesion);
        final repo = _RepoQueCarga(
          (r) async => r.actual.copiar(desdeCopia: true),
          datos: base.datos,
          personaId: sesion.persona.id,
        );
        addTearDown(repo.cerrar);
        addTearDown(base.cerrar);
        await _montar(tester, repo, dispositivo: dispositivo);
        await irA(tester, Rutas.finanzas);
        expect(
          find.byKey(const ValueKey('finanzas-sin-conexion')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Sin conexión: ves lo último que se cargó'),
          findsOneWidget,
        );
      });
    });
  }
}
