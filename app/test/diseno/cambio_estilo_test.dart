import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gravity/diseno/diseno.dart';
import 'package:gravity/nucleo/contratos/roles.dart';

import 'ayuda_pruebas.dart';

/// Un estilo distinto, solo para la prueba.
final _estiloPrueba = Estilo(
  id: 'prueba',
  nombre: 'Prueba',
  dia: futuristaDia.copyWith(
    fondo: const Color(0xFFFFF4E8),
    acento: const Color(0xFF7A3E00),
  ),
  noche: futuristaNoche.copyWith(
    fondo: const Color(0xFF140A1E),
    acento: const Color(0xFFFFB347),
    fuenteTitulos: FuentesGravity.lectura,
  ),
);

/// Pantalla con estado propio: si la app se reiniciara, el contador volvería a 0.
class _Contador extends StatefulWidget {
  const _Contador();

  @override
  State<_Contador> createState() => _ContadorState();
}

class _ContadorState extends State<_Contador> {
  int cuenta = 0;

  @override
  Widget build(BuildContext context) {
    final v = ValoresDiseno.de(context);
    return Scaffold(
      body: Column(
        children: [
          Text('cuenta $cuenta'),
          Text('fondo ${v.fondo.toARGB32()}', key: const ValueKey('fondo')),
          TextButton(
            onPressed: () => setState(() => cuenta++),
            child: const Text('sumar'),
          ),
        ],
      ),
    );
  }
}

ValoresDiseno _valores(WidgetTester tester) =>
    ValoresDiseno.de(tester.element(find.byType(_Contador)));

void main() {
  testWidgets('el estilo cambia sin reiniciar la app', (tester) async {
    await montar(tester, const _Contador());

    expect(_valores(tester).fondo, futuristaNoche.fondo);
    await tester.tap(find.text('sumar'));
    await tester.tap(find.text('sumar'));
    await tester.pump();
    expect(find.text('cuenta 2'), findsOneWidget);
    final estadoAntes = tester.state(find.byType(_Contador));

    contenedorDe(
      tester,
      find.byType(_Contador),
    ).read(estiloProvider.notifier).elegir(_estiloPrueba);
    await tester.pump();
    await tester.pump(duracionCambioTema);

    final v = _valores(tester);
    expect(v.fondo, _estiloPrueba.noche.fondo);
    expect(v.acento, _estiloPrueba.noche.acento);
    expect(v.fuenteTitulos, FuentesGravity.lectura);
    expect(
      Theme.of(tester.element(find.byType(_Contador))).scaffoldBackgroundColor,
      _estiloPrueba.noche.fondo,
    );
    // Misma pantalla y mismo estado: no hubo reinicio.
    expect(find.text('cuenta 2'), findsOneWidget);
    expect(tester.state(find.byType(_Contador)), same(estadoAntes));
  });

  testWidgets('el cambio de estilo es suave (pasa por valores intermedios)', (
    tester,
  ) async {
    await montar(tester, const _Contador());
    contenedorDe(
      tester,
      find.byType(_Contador),
    ).read(estiloProvider.notifier).elegir(_estiloPrueba);
    await tester.pump();
    await tester.pump(duracionCambioTema ~/ 2);
    final intermedio = _valores(tester).fondo;
    expect(intermedio, isNot(futuristaNoche.fondo));
    expect(intermedio, isNot(_estiloPrueba.noche.fondo));
    await tester.pump(duracionCambioTema);
    expect(_valores(tester).fondo, _estiloPrueba.noche.fondo);
  });

  testWidgets('elegir por id regresa al Futurista', (tester) async {
    await montar(tester, const _Contador());
    final c = contenedorDe(tester, find.byType(_Contador));
    c.read(estiloProvider.notifier).elegir(_estiloPrueba);
    await tester.pump();
    c.read(estiloProvider.notifier).elegirPorId('futurista');
    await tester.pump();
    await tester.pump(duracionCambioTema);
    expect(_valores(tester).fondo, futuristaNoche.fondo);
    expect(c.read(estiloProvider), estiloFuturista);
  });

  testWidgets('el estilo de día se usa en horario claro', (tester) async {
    await montar(tester, const _Contador(), momento: momentoDia);
    expect(_valores(tester).fondo, futuristaDia.fondo);
    expect(_valores(tester).brillo, Brightness.light);
  });

  group('TemaModulo aplica la personalidad', () {
    ValoresDiseno? capturado;
    final sonda = Builder(
      builder: (context) {
        capturado = ValoresDiseno.de(context);
        return const SizedBox();
      },
    );

    testWidgets('Finanzas: acento índigo, de noche', (tester) async {
      await montar(tester, TemaModulo(modulo: Modulo.finanzas, child: sonda));
      expect(capturado!.acento, PersonalidadModulo.precisa.acentoNoche);
      expect(capturado!.brillo, Brightness.dark);
    });

    testWidgets('Cuidados: siempre claro, alto contraste y sin decoración', (
      tester,
    ) async {
      await montar(tester, TemaModulo(modulo: Modulo.cuidados, child: sonda));
      expect(capturado!.brillo, Brightness.light);
      expect(capturado!.altoContraste, isTrue);
      expect(capturado!.decoracion, isFalse);
      expect(capturado!.densidad, Densidad.grande);
    });

    testWidgets('Bici: alto contraste también de noche', (tester) async {
      await montar(
        tester,
        TemaModulo(
          modulo: Modulo.habitos,
          submodulo: Submodulo.bici,
          child: sonda,
        ),
      );
      expect(capturado!.altoContraste, isTrue);
      expect(capturado!.brillo, Brightness.dark);
      expect(capturado!.acento, PersonalidadModulo.sport.acentoNoche);
    });

    testWidgets('"Igual al estilo" quita el acento pero no las excepciones', (
      tester,
    ) async {
      await montar(
        tester,
        Column(
          children: [
            TemaModulo(
              modulo: Modulo.finanzas,
              child: Builder(
                builder: (context) {
                  capturado = ValoresDiseno.de(context);
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      );
      final c = contenedorDe(tester, find.byType(TemaModulo));
      c
          .read(opcionesPersonalidadProvider.notifier)
          .fijar(Modulo.finanzas, OpcionPersonalidad.igualAlEstilo);
      c
          .read(opcionesPersonalidadProvider.notifier)
          .fijar(Modulo.cuidados, OpcionPersonalidad.igualAlEstilo);
      await tester.pump();
      await tester.pump(duracionCambioTema);
      expect(capturado!.acento, futuristaNoche.acento);
      expect(
        c.read(personalidadProvider(Modulo.cuidados)).altoContraste,
        isTrue,
      );
      expect(
        c.read(personalidadProvider(Modulo.cuidados)).siempreClaro,
        isTrue,
      );
    });
  });
}
