// Registros que el servidor no aceptó (revisión de la Fase 0, I4): se ven y
// la persona decide; nadie ve los de otra persona.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/app_gravity.dart';
import 'package:gravity/nucleo/base_local/base_local.dart';
import 'package:gravity/nucleo/cola/cola_sin_conexion.dart';
import 'package:gravity/nucleo/cola/proveedores_cola.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';
import 'package:gravity/nucleo/sesion/servicio_sesion_demostracion.dart';

import 'ayuda_plataforma.dart';

class EnviadorSinPermiso implements Enviador {
  @override
  Future<ResultadoEnvio> enviar(PeticionEnvio peticion) async =>
      throw const RechazoEnvio('Sin permiso para guardarlo (42501).');
}

const aviso = ValueKey('aviso-registros-atencion');

void main() {
  testWidgets('el aviso aparece, lleva a revisar y desaparece al descartar', (
    tester,
  ) async {
    final base = BaseLocal.enMemoria();
    addTearDown(base.close);
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.telefono,
      sesion: sesionCon(Rol.dueno),
      base: base,
      extras: [enviadorProvider.overrideWithValue(EnviadorSinPermiso())],
    );
    expect(find.byKey(aviso), findsNothing);

    final cola = ProviderScope.containerOf(
      tester.element(find.byType(AppGravity)),
    ).read(colaSinConexionProvider);
    await cola.encolar(
      tipo: 'finanzas.gasto',
      carga: const {'descripcion': 'Despensa (ejemplo)'},
    );
    // Lo de otra persona en el mismo equipo no se muestra (D5).
    await cola.encolar(
      tipo: 'finanzas.gasto',
      carga: const {'descripcion': 'De otra persona'},
      personaId: sesionDeEjemplo(Rol.familiar).persona.id,
    );
    await cola.procesar();
    await tester.pumpAndSettle();

    expect(find.byKey(aviso), findsOneWidget);
    expect(
      find.text('1 registro no se pudo subir: requiere atención.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Revisar'));
    await tester.pumpAndSettle();
    expect(find.text('Por revisar'), findsOneWidget);
    expect(find.text('finanzas.gasto · Despensa (ejemplo)'), findsOneWidget);
    expect(find.text('Sin permiso para guardarlo (42501).'), findsOneWidget);
    expect(find.textContaining('De otra persona'), findsNothing);

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.byKey(aviso), findsNothing);
    expect(find.text('Todo lo que registraste ya se subió.'), findsOneWidget);
  });
}
