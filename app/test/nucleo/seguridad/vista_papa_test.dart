// D24, criterios 3 y 6 de fase-4-vista-temporal: bloqueo activo durante la
// vista y ausente fuera de ella; el aviso al dueño sin montos ni nombres.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/app/pantalla_segura.dart';
import 'package:gravity/app/sesion_efectiva.dart';
import 'package:gravity/nucleo/avisos/catalogo_avisos.dart';
import 'package:gravity/nucleo/seguridad/pantalla_segura.dart';
import 'package:gravity/nucleo/seguridad/vista_papa_activa.dart';

import 'pantalla_segura_test.dart' show ProtectorRegistrador;

void main() {
  group('bloqueo de capturas en la vista temporal', () {
    late ProtectorRegistrador protector;
    late ProviderContainer c;

    setUp(() {
      protector = ProtectorRegistrador();
      c = ProviderContainer(
        overrides: [
          protectorDePantallaProvider.overrideWithValue(protector),
          rolEfectivoProvider.overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);
    });

    Future<void> monta(WidgetTester t, Widget hijo) => t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(home: hijo),
      ),
    );

    testWidgets('protegida solo mientras la vista está vigente', (t) async {
      await monta(t, const VistaPapaSegura(child: Text('Papá')));
      final ctl = c.read(controladorPantallaSeguraProvider);
      await ctl.aplicado;
      expect(ctl.segura, isFalse, reason: 'fuera de la vista no se bloquea');
      expect(protector.cambios, isEmpty);

      c.read(vistaPapaActivaProvider.notifier).abrir();
      await t.pump();
      await ctl.aplicado;
      expect(ctl.segura, isTrue);
      expect(protector.segura, isTrue);

      c.read(vistaPapaActivaProvider.notifier).cerrar();
      await t.pump();
      await ctl.aplicado;
      expect(ctl.segura, isFalse);
      expect(protector.cambios, [true, false]);
    });

    testWidgets('la guardia del cascarón respeta la vista', (t) async {
      await monta(
        t,
        const GuardiaDePantallaSegura(ubicacion: '/otra', child: Text('x')),
      );
      final ctl = c.read(controladorPantallaSeguraProvider);
      expect(ctl.segura, isFalse);
      c.read(vistaPapaActivaProvider.notifier).abrir();
      await t.pump();
      expect(ctl.segura, isTrue);
      c.read(vistaPapaActivaProvider.notifier).cerrar();
      await t.pump();
      expect(ctl.segura, isFalse);
    });

    testWidgets('al salir de la pantalla se libera aunque siga vigente', (
      t,
    ) async {
      c.read(vistaPapaActivaProvider.notifier).abrir();
      await monta(t, const VistaPapaSegura(child: Text('Papá')));
      final ctl = c.read(controladorPantallaSeguraProvider);
      expect(ctl.segura, isTrue);
      await monta(t, const SizedBox());
      expect(ctl.segura, isFalse);
    });
  });

  group('aviso de solicitud de vista', () {
    test('está en el catálogo, es discreto y no lleva montos ni nombres', () {
      final texto = tituloDeAviso('solicitud_vista');
      expect(texto, 'Solicitud de vista: Familiar');
      expect(titulosDeAviso.containsKey('solicitud_vista'), isTrue);
      expect(textoDeAvisoEsDiscreto(texto), isTrue);
      expect(texto, isNot(contains('Papá')));
      expect(severidadDe('solicitud_vista'), SeveridadAviso.critica);
    });
  });
}
