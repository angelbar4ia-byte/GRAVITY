// HALLAZGO I6 (IMPORTANTE; bloquea llevar dinero a la tablet en la Fase 1)
// · docs/revisiones/fase-0.md
//
// Prueba de regresión: el hallazgo se resolvió el 20/oct/2026 (docs/revisiones/fase-0.md, sección 11).
// Excluir mientras tanto: flutter test --exclude-tags hallazgo
//
// En la tablet, el modo Casa y el cambio de persona son solo de interfaz: la
// sesión del servidor es la de la cuenta con la que se entró en la tablet. Hoy
// la tablet acepta la cuenta del Dueño y aun así muestra "modo Casa"
// (test/app/tablet_test.dart lo prueba a propósito: "aun con la cuenta del
// Dueño"). Así, desde la Fase 1, lo que se consulte en modo Casa corre con los
// permisos del Dueño en el servidor (RLS ve dinero), y quien entra con PIN
// escribe con la identidad de la tablet (bitácora con otro nombre, D5).
// D14: "Modo Casa en reposo: usa la cuenta de rol Casa".
//
// Arreglo mínimo esperado: la tablet solo presenta el modo Casa con la cuenta
// de rol Casa (con otra cuenta, avisa y pide la cuenta Casa).
@Tags(['hallazgo'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/nucleo/contratos/dispositivo.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import '../app/ayuda_plataforma.dart';

void main() {
  testWidgets('con la cuenta del Dueño la tablet no se presenta como modo Casa', (
    tester,
  ) async {
    await montarApp(
      tester,
      dispositivo: TipoDispositivo.tablet,
      sesion: sesionCon(Rol.dueno),
      almacen: await almacenConPersonas({Rol.cuidador: '5678'}),
    );
    expect(find.text('GRAVITY · Casa'), findsNothing);
  });
}
