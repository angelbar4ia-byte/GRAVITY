import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import '../ayuda_plataforma.dart';

void main() {
  testWidgets('depurar', (tester) async {
    final sesion = sesionCon(Rol.casa);
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesion,
      almacen: await almacenConPersonas({Rol.dueno: '1234'}),
    );
    await tester.tap(find.text('Dueño de ejemplo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-pin')), '1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // ignore: avoid_print
    print('animando: ${tester.binding.hasScheduledFrame} transitorios: ${tester.binding.transientCallbackCount}');
    // ignore: avoid_print
    print(find.byType(CircularProgressIndicator).evaluate().length);
    // ignore: avoid_print
    print(find.byType(Dialog).evaluate().length);
    // ignore: avoid_print
    print(tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join(' | '));
    // ignore: avoid_print
    print('servidor: ${sesion.personaEnServidor}');
  });
}
