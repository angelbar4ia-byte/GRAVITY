// Revisión de calidad del bloque 6 de Finanzas (Fase 8), hallazgo H-02.
// Con los montos ocultos, tocar «Editar» en la hoja «Repartir ingreso» deja los
// campos de texto con los montos de cada renglón ya escritos: se ven las cifras
// sin pasar por «Mostrar montos» (que pide PIN o huella). La hoja ya cuida este
// caso al CAMBIAR un reparto (`_editando = cambiando && !montosOcultos`), pero no
// al repartir un ingreso nuevo.
//
// Esta prueba DEBE FALLAR mientras el defecto exista y pasar cuando se corrija
// (por ejemplo: no rellenar los campos con el monto mientras estén ocultos).
import 'package:finanzas_dominio/finanzas_dominio.dart'
    hide Semaforo, formatearCentavos, TipoLibro, puntosBaseEnCien;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/diseno/diseno.dart' show montosVisiblesProvider;
import 'package:gravity/modulos/finanzas/estado/proveedores.dart';
import 'package:gravity/modulos/finanzas/finanzas.dart' show SeccionFinanzas;
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import '../modulos/finanzas/ayuda_finanzas.dart';
import 'ayuda_calidad.dart';

ProviderContainer _contenedor(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(AppGravity)));

void main() {
  testWidgets(
    'H-02: con los montos ocultos, «Editar» no deja ver los montos de los '
    'renglones',
    (tester) async {
      final repo = await montarFinanzasConTamano(
        tester,
        dispositivo: TipoDispositivo.telefono,
        tamano: const Size(360, 800),
        rol: Rol.dueno,
      );
      final ctx = _contenedor(tester).read(contextoFinanzasProvider).value!;
      final base = servicioDe(repo, sesionDe(Rol.dueno));
      final r = await base.registrarIngresoExtra(
        libroId: ctx.libroId,
        monto: 900000,
        cuentaDestinoId: ctx.datos
            .cuentasDe(ctx.libroId)
            .firstWhere((x) => x.tipo == TipoCuenta.banco)
            .id,
        fecha: Fecha(2026, 10, 16),
        nota: 'Sueldo',
      );
      final id = r.movimientos.single.id;
      await base.crearCuenta(
        libroId: ctx.libroId,
        nombre: 'Mi ahorro',
        tipo: TipoCuenta.ahorro,
      );
      await avanzar(tester);
      await irA(tester, SeccionFinanzas.semana.ruta);
      // Montos OCULTOS (el estado normal al abrir; fijar(false) = ocultos).
      _contenedor(tester).read(montosVisiblesProvider.notifier).fijar(false);
      await tester.pumpAndSettle();

      final boton = find.byKey(ValueKey('por-repartir-repartir-$id'));
      await tester.ensureVisible(boton);
      await tester.pumpAndSettle();
      await tester.tap(boton);
      await tester.pumpAndSettle();

      // Antes de «Editar»: sin cifras (esto ya lo prueba el equipo).
      expect(
        find.descendant(
          of: find.byType(Scaffold),
          matching: find.textContaining(r'$'),
        ),
        findsNothing,
        reason: 'precondición: la hoja no muestra cifras con los montos ocultos',
      );

      await tester.tap(find.byKey(const ValueKey('repartir-editar')));
      await tester.pumpAndSettle();

      // Los campos de renglón no deben traer el monto escrito.
      final campos = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.key is ValueKey &&
            '${(w.key! as ValueKey).value}'.startsWith('repartir-linea-'),
      );
      expect(campos, findsWidgets, reason: 'la hoja abrió en modo edición');
      final reveladores = [
        for (final e in campos.evaluate())
          if (RegExp(r'[1-9]').hasMatch(
            ((e.widget as TextField).controller?.text) ?? '',
          ))
            (e.widget as TextField).controller!.text,
      ];
      expect(
        reveladores,
        isEmpty,
        reason:
            'Con los montos ocultos, los campos de «Editar» muestran '
            'cifras: $reveladores',
      );
    },
  );
}
