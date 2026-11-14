import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/modulos/ajustes/google/conexion_google.dart';
import 'package:gravity/modulos/ajustes/google/tarjeta_google.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

class _Falsa implements ConexionGoogle {
  final pedidas = <AmbitoGoogle>[];
  @override
  Future<Uri> urlDeConexion(AmbitoGoogle ambito) async {
    pedidas.add(ambito);
    return Uri.parse('https://accounts.google.com/o/oauth2/v2/auth?x=1');
  }

  @override
  Future<EstadoGoogle> estado(AmbitoGoogle ambito) async =>
      const EstadoGoogle(conectada: false);
}

Future<_Falsa> _montar(
  WidgetTester tester,
  Rol rol, {
  bool esMaestra = false,
  List<Uri>? abiertas,
}) async {
  final f = _Falsa();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        conexionGoogleProvider.overrideWithValue(f),
        abrirUrlGoogleProvider.overrideWithValue((u) async {
          abiertas?.add(u);
          return true;
        }),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SeccionGoogleAjustes(rol: rol, esMaestra: esMaestra),
        ),
      ),
    ),
  );
  await tester.pump();
  return f;
}

void main() {
  test('quién puede conectar', () {
    for (final r in [Rol.dueno, Rol.coadministrador, Rol.familiar]) {
      expect(puedeConectarGooglePersonal(r), isTrue, reason: '$r');
    }
    expect(puedeConectarGooglePersonal(Rol.cuidador), isFalse);
    expect(puedeConectarGooglePersonal(Rol.casa), isFalse);
    expect(
      puedeConectarGooglePersonal(Rol.coadministrador, esMaestra: true),
      isFalse,
    );
    expect(puedeConectarGoogleCasa(Rol.dueno), isTrue);
    for (final r in [
      Rol.coadministrador,
      Rol.familiar,
      Rol.cuidador,
      Rol.casa,
    ]) {
      expect(puedeConectarGoogleCasa(r), isFalse, reason: '$r');
    }
  });

  testWidgets('la cuidadora y Casa no ven ningún botón', (tester) async {
    for (final rol in [Rol.cuidador, Rol.casa]) {
      await _montar(tester, rol);
      expect(find.textContaining('Conectar'), findsNothing, reason: '$rol');
    }
  });

  testWidgets('el familiar ve solo el botón personal', (tester) async {
    await _montar(tester, Rol.familiar);
    expect(find.text('Conectar cuenta de Google'), findsOneWidget);
    expect(find.textContaining('de la casa'), findsNothing);
  });

  testWidgets('el dueño conecta: pide la URL y la abre en el navegador', (
    tester,
  ) async {
    final abiertas = <Uri>[];
    final f = await _montar(tester, Rol.dueno, abiertas: abiertas);
    expect(find.text('Conectar cuenta de Google de la casa'), findsOneWidget);
    await tester.tap(find.text('Conectar cuenta de Google'));
    await tester.pump();
    await tester.pump();
    expect(f.pedidas, [AmbitoGoogle.personal]);
    expect(abiertas.single.host, 'accounts.google.com');
  });
}
